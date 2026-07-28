require "rails_helper"

RSpec.describe "Deals", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: pipeline.pipeline_stages.find_by(name: "Proposal")) }

  describe "GET /deals/picker" do
    it "returns open and won deals matching the query, excluding lost and other workspaces" do
      won = pipeline.pipeline_stages.find_by!(name: "Won")
      lost = pipeline.pipeline_stages.find_by!(name: "Lost")
      open_deal = create_deal!(workspace, pipeline: pipeline, name: "Curso IA abierto")
      won_deal = create_deal!(workspace, pipeline: pipeline, stage: won, name: "Curso IA ganado")
      create_deal!(workspace, pipeline: pipeline, stage: lost, name: "Curso IA perdido")
      other_pipeline = Pipeline.create_default!(workspaces(:two))
      create_deal!(workspaces(:two), pipeline: other_pipeline, name: "Curso IA ajeno")
      sign_in_as(member)

      get picker_deals_path(q: "Curso IA"), as: :json

      names = JSON.parse(response.body).map { |d| d["name"] }
      expect(names).to contain_exactly("Curso IA abierto", "Curso IA ganado")
      won_row = JSON.parse(response.body).find { |d| d["name"] == "Curso IA ganado" }
      expect(won_row["won"]).to be(true)
      expect(won_row["stage"]).to eq("Won")
    end
  end

  describe "POST /deals" do
    it "creates a deal with company, contacts and a next-action task" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)

      expect {
        post deals_path, params: { deal: {
          name: "ACME — Annual", company_id: company.id, pipeline_id: pipeline.id,
          contact_ids: [ contact.id ],
          tasks_attributes: { "0" => { title: "Kickoff call", due_on: (Date.current + 5).to_s } }
        } }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(response).to redirect_to(deal_path(deal))
      expect(deal.contacts).to contain_exactly(contact)
      expect(deal.tasks.map(&:title)).to include("Kickoff call")
      expect(deal.pipeline_stage).to eq(pipeline.first_stage)
    end

    it "creates a deal in a selected pipeline stage" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      target_stage = pipeline.pipeline_stages.find_by!(name: "Qualified")

      expect {
        post deals_path, params: { deal: {
          name: "ACME — Annual", company_id: company.id, pipeline_id: pipeline.id,
          pipeline_stage_id: target_stage.id,
          contact_ids: [ contact.id ],
          tasks_attributes: { "0" => { title: "Kickoff call", due_on: (Date.current + 5).to_s } }
        } }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(deal.pipeline_stage).to eq(target_stage)
    end

    it "creates a deal with product lines and edition" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      product = workspace.products.create!(name: "Premium", price: 1200)

      expect {
        post deals_path, params: { deal: {
          name: "ACME — Annual", company_id: company.id, pipeline_id: pipeline.id,
          contact_ids: [ contact.id ],
          tasks_attributes: { "0" => { title: "Kickoff call", due_on: (Date.current + 5).to_s } },
          deal_products_attributes: {
            "0" => { product_id: product.id, edition_name: "2026", quantity: 2 }
          }
        } }
      }.to change(Deal, :count).by(1)
        .and change(DealProduct, :count).by(1)
        .and change(Edition, :count).by(1)

      deal = Deal.order(:id).last
      line = deal.deal_products.first
      expect(line.product).to eq(product)
      expect(line.edition.name).to eq("2026")
      expect(line.quantity).to eq(2)
      expect(deal.value).to eq(2400)
    end

    it "creates a deal with only a company and a next action" do
      sign_in_as(member)
      company = create_company!(workspace)

      expect {
        post deals_path, params: { deal: {
          name: "ACME — Company only", company_id: company.id, pipeline_id: pipeline.id,
          tasks_attributes: { "0" => { title: "Research account", due_on: (Date.current + 5).to_s } }
        } }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(response).to redirect_to(deal_path(deal))
      expect(deal.company).to eq(company)
      expect(deal.contacts).to be_empty
    end

    it "creates a deal with a partner and a partner contact" do
      sign_in_as(member)
      client = create_company!(workspace, name: "Asisa")
      partner = create_company!(workspace, name: "Avantis Group")
      partner_contact = create_person!(workspace, company: partner, first_name: "Laura")

      expect {
        post deals_path, params: { deal: {
          name: "Asisa — Offer", company_id: client.id, partner_id: partner.id, pipeline_id: pipeline.id,
          contact_ids: [ partner_contact.id ],
          tasks_attributes: { "0" => { title: "Send proposal", due_on: (Date.current + 5).to_s } }
        } }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(response).to redirect_to(deal_path(deal))
      expect(deal.company).to eq(client)
      expect(deal.partner).to eq(partner)
      expect(deal.contacts).to contain_exactly(partner_contact)
    end

    it "rejects a deal without a next action" do
      sign_in_as(member)
      company = create_company!(workspace)

      expect {
        post deals_path, params: { deal: { name: "Bad", company_id: company.id, pipeline_id: pipeline.id } }
      }.not_to change(Deal, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "creates a deal from a person quick dialog with product and next action" do
      sign_in_as(member)
      company = create_company!(workspace, name: "ACME Corp")
      person = create_person!(workspace, company: company, first_name: "Jane", last_name: "Doe")
      product = workspace.products.create!(name: "Premium Plan", price: 500)

      expect {
        post deals_path, params: {
          quick_from_person_id: person.id,
          deal: {
            company_id: company.id,
            pipeline_id: pipeline.id,
            pipeline_stage_id: pipeline.first_stage.id,
            contact_ids: [ person.id ],
            deal_products_attributes: { "0" => { product_id: product.id, quantity: 1 } },
            tasks_attributes: { "0" => { title: "Initial call", due_on: (Date.current + 1).to_s } }
          }
        }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(response).to redirect_to(deal_path(deal))
      expect(deal.name).to eq("ACME Corp — Premium Plan")
      expect(deal.company).to eq(company)
      expect(deal.contacts).to contain_exactly(person)
      expect(deal.pipeline_stage).to eq(pipeline.first_stage)
      expect(deal.deal_products.first.product).to eq(product)
      expect(deal.tasks.map(&:title)).to include("Initial call")
    end

    it "creates a deal in the selected pipeline first stage" do
      sign_in_as(member)
      other = pipeline.duplicate(name: "Partners").tap(&:save!)
      memberships(:one_one).update!(current_pipeline: pipeline)
      company = create_company!(workspace, name: "ACME Corp")
      person = create_person!(workspace, company: company)
      product = workspace.products.create!(name: "Premium Plan", price: 500)

      expect {
        post deals_path, params: {
          quick_from_person_id: person.id,
          deal: {
            company_id: company.id,
            pipeline_id: other.id,
            contact_ids: [ person.id ],
            deal_products_attributes: { "0" => { product_id: product.id, quantity: 1 } },
            tasks_attributes: { "0" => { title: "Initial call", due_on: (Date.current + 1).to_s } }
          }
        }
      }.to change(Deal, :count).by(1)

      deal = Deal.order(:id).last
      expect(deal.pipeline).to eq(other)
      expect(deal.pipeline_stage).to eq(other.first_stage)
    end

    it "returns turbo stream with errors in the modal when quick create fails validation" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company)
      product = workspace.products.create!(name: "Basic", price: 100)
      turbo_headers = { "Accept" => "text/vnd.turbo-stream.html" }

      expect {
        post deals_path, params: {
          quick_from_person_id: person.id,
          deal: {
            company_id: company.id,
            pipeline_id: pipeline.id,
            contact_ids: [ person.id ],
            deal_products_attributes: { "0" => { product_id: product.id, quantity: 1 } },
            tasks_attributes: { "0" => { title: "", due_on: (Date.current + 1).to_s } }
          }
        }, headers: turbo_headers
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(person, :quick_deal_form))
      expect(response.body).to include("Tasks title can&#39;t be blank")
    end
  end

  describe "GET /deals (stage sort)" do
    it "orders by pipeline stage position when a pipeline is selected" do
      sign_in_as(member)
      memberships(:one_one).update!(current_pipeline: pipeline)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      lead_stage = pipeline.pipeline_stages.find_by(name: "Lead")
      proposal_stage = pipeline.pipeline_stages.find_by(name: "Proposal")
      create_deal!(workspace, pipeline: pipeline, stage: proposal_stage, name: "Late stage",
        company: company, contacts: [ contact ], position: 0)
      create_deal!(workspace, pipeline: pipeline, stage: lead_stage, name: "Early stage",
        company: company, contacts: [ contact ], position: 0)

      get deals_path, params: { sort: "stage", dir: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.body.index("Early stage")).to be < response.body.index("Late stage")
    end

    it "shows a sortable stage column when a pipeline is selected" do
      sign_in_as(member)
      memberships(:one_one).update!(current_pipeline: pipeline)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      create_deal!(workspace, company: company, contacts: [ contact ])

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("sort=stage")
    end

    it "shows contact email and phone in the table when present" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company,
        first_name: "Ana", last_name: "García", email: "ana@acme.com", phone: "+34 600 000 000")
      create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ contact ], name: "Contact info deal")

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ana")
      expect(response.body).to include("García")
      expect(response.body).to include("ana@acme.com")
      expect(response.body).to include("+34 600 000 000")
      expect(response.body).to include('class="text-ink-soft select-text cursor-text"')
    end
  end

  describe "GET /deals (active pipeline filter)" do
    it "filters the index by the active pipeline" do
      sign_in_as(member)
      other = pipeline.duplicate(name: "Partners").tap(&:save!)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      create_deal!(workspace, pipeline: pipeline, name: "Ventas deal", company: company, contacts: [ contact ])
      create_deal!(workspace, pipeline: other, name: "Partners deal", company: company, contacts: [ contact ])
      memberships(:one_one).update!(current_pipeline: pipeline)

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ventas deal")
      expect(response.body).not_to include("Partners deal")
    end

    it "shows all deals when all pipelines is selected" do
      sign_in_as(member)
      other = pipeline.duplicate(name: "Partners").tap(&:save!)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      create_deal!(workspace, pipeline: pipeline, name: "Ventas deal", company: company, contacts: [ contact ])
      create_deal!(workspace, pipeline: other, name: "Partners deal", company: company, contacts: [ contact ])
      memberships(:one_one).update!(current_pipeline: nil)

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ventas deal")
      expect(response.body).to include("Partners deal")
    end
  end

  describe "GET /deals (pagination)" do
    it "paginates the index at 50 per page" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      51.times { create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ contact ]) }

      get deals_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 1 de 2")
      expect(response.body).to include("Siguiente")

      get deals_path, params: { page: 2 }
      expect(response.body).to include("Página 2 de 2")
    end
  end

  describe "GET /deals (list filters)" do
    it "filters unassigned deals with owner_id=none" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      unassigned = create_deal!(workspace, pipeline: pipeline, name: "No owner deal",
        company: company, contacts: [ contact ], owner: nil)
      create_deal!(workspace, pipeline: pipeline, name: "Owned deal",
        company: company, contacts: [ contact ], owner: member)

      get deals_path(owner_id: ListFilters::NONE, pipeline_id: pipeline.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unassigned.name)
      expect(response.body).not_to include("Owned deal")
    end

    it "filters deals by created_at range" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      recent = create_deal!(workspace, pipeline: pipeline, name: "Recent deal",
        company: company, contacts: [ contact ])
      recent.update_column(:created_at, Time.zone.local(2025, 6, 10, 12))
      old = create_deal!(workspace, pipeline: pipeline, name: "Old deal",
        company: company, contacts: [ contact ])
      old.update_column(:created_at, Time.zone.local(2025, 1, 10, 12))

      get deals_path(created_from: "2025-06-01", created_to: "2025-06-30", pipeline_id: pipeline.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recent deal")
      expect(response.body).not_to include("Old deal")
    end

    it "shows deals from all pipelines when pipeline_id=all" do
      sign_in_as(member)
      other_pipeline = pipeline.duplicate(name: "Hiring").tap(&:save!)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      create_deal!(workspace, pipeline: pipeline, name: "Default pipeline deal",
        company: company, contacts: [ contact ])
      create_deal!(workspace, pipeline: other_pipeline, name: "Other pipeline deal",
        company: company, contacts: [ contact ])
      memberships(:one_one).update!(current_pipeline: pipeline)

      get deals_path(pipeline_id: "all")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Default pipeline deal")
      expect(response.body).to include("Other pipeline deal")
    end
  end

  describe "GET /deals (closed stages)" do
    it "hides closed-stage deals from the index by default" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Closed deal",
        company: company, contacts: [ contact ])

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Closed deal")
    end

    it "shows closed-stage deals on the index when closed=1" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      create_deal!(workspace, pipeline: pipeline, stage: won_stage, name: "Closed deal",
        company: company, contacts: [ contact ])

      get deals_path, params: { closed: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Closed deal")
    end
  end

  describe "GET /deals/board (saved views)" do
    let(:company) { create_company!(workspace) }
    let(:product) { workspace.products.create!(name: "Premium", price: 100) }
    let(:edition) { workspace.editions.create!(name: "2026") }

    def filtered_deal(name:, contact_date: Date.new(2026, 1, 15))
      contact = create_person!(workspace, company: company, first_contact_on: contact_date)
      deal = create_deal!(workspace, pipeline: pipeline, name: name, company: company, contacts: [ contact ])
      deal.deal_products.create!(product: product, edition: edition, quantity: 1)
      deal
    end

    it "renders view tabs on the board" do
      sign_in_as(member)

      get board_deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Save view")
      expect(response.body).to include('href="/deals/board?clear_filters=1"')
    end

    it "applies a saved view on the board" do
      sign_in_as(member)
      filtered_deal(name: "View match")
      filtered_deal(name: "View other", contact_date: Date.new(2026, 3, 1))
      view = SavedView.create!(
        workspace: workspace,
        user: member,
        record_type: "Deal",
        name: "Board product view",
        filters: {
          "product_id" => product.id.to_s,
          "edition_id" => edition.id.to_s,
          "first_contact_from" => "2026-01-01",
          "first_contact_to" => "2026-02-01"
        }
      )

      get board_deals_path(view: view.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("View match")
      expect(response.body).not_to include("View other")
      expect(response.body).to include("Board product view")
    end

    it "does not show Update view when the saved view only differs by stage" do
      sign_in_as(member)
      lead_stage = pipeline.pipeline_stages.find_by!(name: "Lead")
      view = SavedView.create!(
        workspace: workspace,
        user: member,
        record_type: "Deal",
        name: "Lead stage view",
        filters: { "stage" => lead_stage.id.to_s }
      )

      get board_deals_path(view: view.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Update view")
    end
  end

  describe "GET /deals/board (closed stages)" do
    it "hides closed stage columns by default" do
      sign_in_as(member)
      get board_deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("stage_summary_#{pipeline.pipeline_stages.find_by(name: 'Won').id}")
      expect(response.body).not_to include("stage_summary_#{pipeline.pipeline_stages.find_by(name: 'Lost').id}")
    end

    it "shows closed stage columns when closed=1" do
      sign_in_as(member)
      get board_deals_path, params: { closed: "1" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("stage_summary_#{pipeline.pipeline_stages.find_by(name: 'Won').id}")
      expect(response.body).to include("stage_summary_#{pipeline.pipeline_stages.find_by(name: 'Lost').id}")
    end

    it "hides closed stage columns again after toggling them off" do
      sign_in_as(member)
      won = pipeline.pipeline_stages.find_by!(name: "Won")

      get board_deals_path, params: { closed: "1" }
      expect(response.body).to include("stage_summary_#{won.id}")

      get board_deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("stage_summary_#{won.id}")
    end

    it "hides closed stage columns when they are not the last stages" do
      sign_in_as(member)
      stages = pipeline.pipeline_stages.ordered.to_a
      won = stages.find { |s| s.name == "Won" }
      lost = stages.find { |s| s.name == "Lost" }
      lead = stages.find { |s| s.name == "Lead" }
      pipeline.reorder_stages!([ lead.id, won.id, lost.id ] + stages.reject { |s| [ won, lost, lead ].include?(s) }.map(&:id))

      get board_deals_path, params: { closed: "1" }
      expect(response.body).to include("stage_summary_#{won.id}")

      get board_deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("stage_summary_#{won.id}")
      expect(response.body).not_to include("stage_summary_#{lost.id}")
    end
  end

  describe "GET /deals (filters)" do
    let(:company) { create_company!(workspace) }
    let(:lead_stage) { pipeline.pipeline_stages.find_by!(name: "Lead") }
    let(:product) { workspace.products.create!(name: "Premium", price: 100) }
    let(:edition) { workspace.editions.create!(name: "2026") }

    def filtered_deal(name:, stage: lead_stage, product_line: product, edition_line: edition, contact_date: Date.new(2026, 1, 15))
      contact = create_person!(workspace, company: company, first_contact_on: contact_date)
      deal = create_deal!(workspace, pipeline: pipeline, stage: stage, name: name, company: company, contacts: [ contact ])
      deal.deal_products.create!(product: product_line, edition: edition_line, quantity: 1)
      deal
    end

    it "filters the index by product, edition and first contact range" do
      sign_in_as(member)
      filtered_deal(name: "Matching deal")
      filtered_deal(name: "Other edition", edition_line: workspace.editions.create!(name: "2025"))
      filtered_deal(name: "Other date", contact_date: Date.new(2026, 3, 1))

      get deals_path, params: {
        product_id: product.id,
        edition_id: edition.id,
        first_contact_from: "2026-01-01",
        first_contact_to: "2026-02-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Matching deal")
      expect(response.body).not_to include("Other edition")
      expect(response.body).not_to include("Other date")
    end

    it "filters the board by the same params" do
      sign_in_as(member)
      filtered_deal(name: "Board match")
      filtered_deal(name: "Board other", contact_date: Date.new(2026, 3, 1))

      get board_deals_path, params: {
        product_id: product.id,
        edition_id: edition.id,
        first_contact_from: "2026-01-01",
        first_contact_to: "2026-02-01"
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Board match")
      expect(response.body).not_to include("Board other")
    end

    it "renders the filter controls on both views" do
      sign_in_as(member)

      get deals_path
      expect(response.body).to include('name="stage"')
      expect(response.body).to include('name="product_id"')
      expect(response.body).to include('name="first_contact_from"')

      get board_deals_path
      expect(response.body).not_to include('name="stage"')
      expect(response.body).to include('name="product_id"')
      expect(response.body).to include('name="first_contact_to"')
    end

    it "ignores stage filter on the board even when passed in params" do
      sign_in_as(member)
      lead_stage = pipeline.pipeline_stages.find_by!(name: "Lead")
      qualified_stage = pipeline.pipeline_stages.find_by!(name: "Qualified")
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      lead_deal = create_deal!(workspace, pipeline: pipeline, stage: lead_stage, name: "Lead only",
        company: company, contacts: [ contact ])
      create_deal!(workspace, pipeline: pipeline, stage: qualified_stage, name: "Qualified only",
        company: company, contacts: [ contact ])

      get board_deals_path, params: { stage: lead_stage.id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Lead only")
      expect(response.body).to include("Qualified only")
    end
  end

  describe "GET /deals/board (card fields)" do
    def board_card_html(deal_id)
      response.body[/data-deal-id="#{deal_id}"[\s\S]*?<\/article>/]
    end

    let(:company) { create_company!(workspace, name: "Acme Corp") }
    let(:product) { workspace.products.create!(name: "Premium", price: 100) }
    let(:edition) { workspace.editions.create!(name: "2026") }

    it "does not show products on cards when products is not selected" do
      sign_in_as(member)
      deal = create_deal!(workspace, pipeline: pipeline, name: "No products shown", company: company)
      deal.deal_products.create!(product: product, edition: edition, quantity: 2)

      get board_deals_path

      card = board_card_html(deal.id)
      expect(card).to include("No products shown")
      expect(card).not_to include("Premium")
      expect(card).not_to include("2026")
    end

    it "shows products and editions on cards when products is selected" do
      sign_in_as(member)
      pipeline.update!(card_fields: pipeline.card_fields + [ "products" ])
      deal = create_deal!(workspace, pipeline: pipeline, name: "With products", company: company)
      deal.deal_products.create!(product: product, edition: edition, quantity: 2)

      get board_deals_path

      card = board_card_html(deal.id)
      expect(card).to include("With products")
      expect(card).to include("Premium")
      expect(card).to include("2026")
      expect(card).to include("×2")
    end

    it "hides company on cards when company is not selected" do
      sign_in_as(member)
      pipeline.update!(card_fields: %w[value owner])
      deal = create_deal!(workspace, pipeline: pipeline, name: "No company shown", company: company)

      get board_deals_path

      card = board_card_html(deal.id)
      expect(card).to include("No company shown")
      expect(card).not_to include("Acme Corp")
    end
  end

  describe "GET /deals/board (task indicator)" do
    def board_card_html(deal_id)
      response.body[/data-deal-id="#{deal_id}"[\s\S]*?<\/article>/]
    end

    it "shows a hoki task icon when the deal has a pending non-overdue task" do
      sign_in_as(member)
      on_track = create_deal!(workspace, name: "On track deal")

      get board_deals_path

      card = board_card_html(on_track.id)
      expect(card).to include("On track deal")
      expect(card).to include("text-hoki-600")
      expect(card).not_to include("text-danger")
      expect(card).to include("Next action")
      expect(card).to include(on_track.tasks.first.assignee.name)
    end

    it "shows a red task icon when the deal has an overdue pending task" do
      sign_in_as(member)
      overdue = create_deal!(workspace, name: "Overdue deal")
      overdue.tasks.first.update!(due_on: Date.current - 2)

      get board_deals_path

      card = board_card_html(overdue.id)
      expect(card).to include("Overdue deal")
      expect(card).to include("text-danger")
      expect(card).to include("Next action")
    end

    it "shows no task icon when the deal has no pending tasks" do
      sign_in_as(member)
      completed = create_deal!(workspace, name: "Completed only deal")
      completed.tasks.update_all(completed_at: Time.current)

      get board_deals_path

      card = board_card_html(completed.id)
      expect(card).to include("Completed only deal")
      expect(card).not_to include("text-hoki-600")
      expect(card).not_to include("text-danger")
    end
  end

  describe "PATCH /deals/:id/move (kanban)" do
    it "responds with a turbo stream that refreshes the stage summaries" do
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by(name: "Won")

      patch move_deal_path(deal), params: { pipeline_stage_id: target.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("stage_summary_#{target.id}")
      expect(deal.reload.stage_label).to eq("Won")
    end

    it "responds with a turbo stream that refreshes the show page stage selector" do
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by(name: "Won")

      patch move_deal_path(deal), params: { pipeline_stage_id: target.id, source: "show" },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('turbo-stream action="replace" target="deal_stage_badge"')
      expect(response.body).to include('turbo-stream action="replace" target="deal_stage_stepper"')
      expect(response.body).to include('data-controller="deal-stage-celebration"')
      expect(deal.reload.stage_label).to eq("Won")
    end

    it "returns 422 with a toast when stage conditions block the move" do
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by!(name: "Qualified")
      workspace.stage_conditions.create!(pipeline_stage: target, field: "value",
        operator: "gt", compare_value: "10000")
      deal.update_column(:value, 100)
      original_stage = deal.pipeline_stage

      patch move_deal_path(deal), params: { pipeline_stage_id: target.id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('target="toasts"')
      expect(response.body).to include("No se puede pasar")
      expect(deal.reload.pipeline_stage).to eq(original_stage)
    end
  end

  describe "PATCH /deals/:id (stage change through the edit form)" do
    it "routes stage changes through move_to_stage! so activity and hooks fire" do
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by(name: "Won")

      expect {
        patch deal_path(deal), params: { deal: { name: "Renamed", pipeline_stage_id: target.id } }
      }.to change { deal.activities.where(action: "stage_changed").count }.by(1)

      expect(deal.reload.stage_label).to eq("Won")
      expect(deal.name).to eq("Renamed")
      expect(deal.activities.where(action: "stage_changed").last.metadata).to include("to" => "Won")
    end

    it "enqueues stage triggers when the stage changes" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(true)
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by(name: "Won")
      workspace.stage_triggers.create!(name: "T", pipeline_stage: target,
        execution_mode: "llm", instructions: "x")

      expect {
        patch deal_path(deal), params: { deal: { pipeline_stage_id: target.id } }
      }.to have_enqueued_job(StageTriggerJob)
    end

    it "does not log stage_changed when the stage stays the same" do
      sign_in_as(member)

      expect {
        patch deal_path(deal), params: { deal: { name: "Renamed", pipeline_stage_id: deal.pipeline_stage_id } }
      }.not_to change { deal.activities.where(action: "stage_changed").count }

      expect(deal.reload.name).to eq("Renamed")
    end

    it "updates the partner and partner contact" do
      sign_in_as(member)
      partner = create_company!(workspace, name: "Avantis Group")
      partner_contact = create_person!(workspace, company: partner, first_name: "Laura")

      patch deal_path(deal), params: { deal: { partner_id: partner.id, contact_ids: [ partner_contact.id ] } }

      expect(response).to redirect_to(deal_path(deal))
      expect(deal.reload.partner).to eq(partner)
      expect(deal.contacts).to contain_exactly(partner_contact)
    end

    it "keeps the original stage and shows an error when conditions block the change" do
      sign_in_as(member)
      target = pipeline.pipeline_stages.find_by!(name: "Qualified")
      original_stage = deal.pipeline_stage
      workspace.stage_conditions.create!(pipeline_stage: target, field: "value",
        operator: "gt", compare_value: "10000")
      deal.update_column(:value, 100)

      patch deal_path(deal), params: { deal: { name: "Should not save", pipeline_stage_id: target.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("No se puede pasar")
      expect(deal.reload.pipeline_stage).to eq(original_stage)
      expect(deal.name).not_to eq("Should not save")
    end
  end

  describe "PATCH /deals/:id/move_pipeline" do
    it "moves the deal to another pipeline's initial stage" do
      sign_in_as(member)
      other = workspace.pipelines.create!(name: "Partners", position: 1,
        pipeline_stages: [ PipelineStage.new(name: "New lead", color: "hoki", probability: 5, position: 0, workspace: workspace) ])

      patch move_pipeline_deal_path(deal), params: { pipeline_id: other.id }

      expect(response).to redirect_to(deal_path(deal))
      expect(deal.reload.pipeline).to eq(other)
      expect(deal.pipeline_stage).to eq(other.first_stage)
    end
  end

  describe "GET /deals/:id/edit" do
    it "renders stage data attributes and celebration controller on the form" do
      sign_in_as(member)
      won_stage = pipeline.pipeline_stages.find_by(name: "Won")
      lost_stage = pipeline.pipeline_stages.find_by(name: "Lost")

      get edit_deal_path(deal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="deal-stage-celebration"')
      expect(response.body).to include(
        "data-stage-won=\"true\" data-stage-closed=\"true\" value=\"#{won_stage.id}\""
      )
      expect(response.body).to include(
        "data-stage-won=\"false\" data-stage-closed=\"true\" value=\"#{lost_stage.id}\""
      )
    end
  end

  describe "POST /deals/:id/duplicate" do
    it "creates a duplicate in the workspace and redirects to its show page" do
      sign_in_as(member)
      company = create_company!(workspace)
      contact = create_person!(workspace, company: company)
      source = create_deal!(workspace, pipeline: pipeline, name: "Source deal",
        company: company, contacts: [ contact ], value: 5000)
      source.tasks.create!(title: "Open task", due_on: Date.current + 2,
        workspace: workspace, user: member, assignee: member)
      field = workspace.custom_fields.create!(record_type: "Deal", name: "Tier", field_type: "text")
      source.update!(custom_fields: { field.key => "Gold" })

      expect {
        post duplicate_deal_path(source)
      }.to change(Deal, :count).by(1)

      copy = Deal.order(:id).last
      expect(response).to redirect_to(deal_path(copy))
      expect(flash[:notice]).to eq("Deal duplicado.")
      expect(copy.name).to eq("Source deal (copia)")
      expect(copy.company).to eq(company)
      expect(copy.contacts).to contain_exactly(contact)
      expect(copy.custom_fields_hash[field.key]).to eq("Gold")
      expect(copy.tasks.pending.pluck(:title)).to include("Open task", "Next action")
      expect(copy.deal_products).to be_empty
    end

    it "does not duplicate deals from another workspace" do
      sign_in_as(member)
      other_workspace = workspaces(:two)
      other_pipeline = Pipeline.create_default!(other_workspace)
      other_deal = create_deal!(other_workspace, pipeline: other_pipeline)

      expect {
        post duplicate_deal_path(other_deal)
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "role-based deal visibility" do
    let(:admin) { users(:one) }
    let(:salesperson) { users(:two) }
    let(:director) { users(:three) }

    def sign_in_to_workspace!(user)
      sign_in_as(user)
      patch switch_workspace_path, params: { workspace_id: workspace.id }
    end

    it "limits a salesperson to owned and shared deals on index" do
      own_deal = create_deal!(workspace, pipeline: pipeline, owner: salesperson, name: "Own deal")
      shared_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Shared deal")
      shared_deal.deal_accesses.create!(user: salesperson)
      create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Hidden deal")
      sign_in_to_workspace!(salesperson)

      get deals_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Own deal")
      expect(response.body).to include("Shared deal")
      expect(response.body).not_to include("Hidden deal")
    end

    it "allows admin and sales director to see all deals" do
      create_deal!(workspace, pipeline: pipeline, owner: salesperson, name: "Sales deal")
      create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Admin deal")

      sign_in_to_workspace!(director)
      get deals_path
      expect(response.body).to include("Sales deal")
      expect(response.body).to include("Admin deal")

      sign_in_to_workspace!(admin)
      get deals_path
      expect(response.body).to include("Sales deal")
      expect(response.body).to include("Admin deal")
    end

    it "forbids a salesperson from viewing another user's deal" do
      hidden_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Hidden deal")
      sign_in_to_workspace!(salesperson)

      get deal_path(hidden_deal)

      expect(response).to have_http_status(:not_found)
    end

    it "allows a collaborator to view a shared deal" do
      shared_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Shared deal")
      shared_deal.deal_accesses.create!(user: salesperson)
      sign_in_to_workspace!(salesperson)

      get deal_path(shared_deal)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Shared deal")
      expect(response.body).to include("Colaboradores")
    end
  end
end
