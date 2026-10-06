require "rails_helper"

RSpec.describe Deal, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }

  it "defaults a new deal to the default pipeline's first stage" do
    company = create_company!(workspace)
    actor = workspace.users.first
    created = workspace.deals.create!(name: "No stage given", company: company,
      contacts: [create_person!(workspace, company: company)],
      tasks: [Task.new(title: "Next", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])

    expect(created.pipeline).to eq(pipeline)
    expect(created.stage_label).to eq("Lead")
  end

  it "moves to a stage by id and logs the change" do
    won = pipeline.pipeline_stages.find_by(name: "Won")

    expect { deal.move_to_stage!(won.id) }.to change { deal.reload.stage_label }.from("Lead").to("Won")
    expect(deal.activities.where(action: "stage_changed").last.metadata).to include("from" => "Lead", "to" => "Won", "won" => true)
  end

  it "moves to a stage by name" do
    deal.move_to_stage!("Qualified")
    expect(deal.reload.stage_label).to eq("Qualified")
  end

  it "moves to a stage by name case-insensitively" do
    deal.move_to_stage!("qualified")
    expect(deal.reload.stage_label).to eq("Qualified")
  end

  describe "stage triggers" do
    include ActiveJob::TestHelper

    let(:qualified) { pipeline.pipeline_stages.find_by!(name: "Qualified") }

    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(true)
    end

    it "enqueues a job per active trigger of the target stage" do
      active = workspace.stage_triggers.create!(name: "A", pipeline_stage: qualified,
        execution_mode: "llm", instructions: "x")
      workspace.stage_triggers.create!(name: "B", pipeline_stage: qualified,
        execution_mode: "llm", instructions: "x", active: false)

      expect { deal.move_to_stage!(qualified) }
        .to have_enqueued_job(StageTriggerJob).exactly(:once).with(active, deal, nil)
    end

    it "does not enqueue when the stage does not change" do
      workspace.stage_triggers.create!(name: "A", pipeline_stage: deal.pipeline_stage,
        execution_mode: "llm", instructions: "x")

      expect { deal.move_to_stage!(deal.pipeline_stage) }.not_to have_enqueued_job(StageTriggerJob)
    end

    it "does not enqueue when the feature is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(false)
      workspace.stage_triggers.create!(name: "A", pipeline_stage: qualified,
        execution_mode: "llm", instructions: "x")

      expect { deal.move_to_stage!(qualified) }.not_to have_enqueued_job(StageTriggerJob)
    end
  end

  describe ".sorted_by_next_task" do
    it "orders by earliest pending task due date" do
      stage = pipeline.first_stage
      overdue = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Overdue")
      overdue.tasks.first.update!(due_on: Date.current - 2)
      future = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Future")
      future.tasks.first.update!(due_on: Date.current + 5)

      ordered = workspace.deals.where(id: [overdue.id, future.id]).sorted_by_next_task(:asc)
      expect(ordered.pluck(:id)).to eq([overdue.id, future.id])
    end

    it "orders after product and first-contact filters" do
      stage = pipeline.first_stage
      company = create_company!(workspace)
      product = workspace.products.create!(name: "Filter product", price: 10)
      edition = product.editions.create!(name: "2026")
      contact = create_person!(workspace, company: company, first_contact_on: Date.new(2026, 1, 15))
      overdue = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Overdue", company: company, contacts: [contact])
      overdue.deal_products.create!(product: product, edition: edition, quantity: 1)
      overdue.tasks.first.update!(due_on: Date.current - 2)
      future = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Future", company: company, contacts: [contact])
      future.deal_products.create!(product: product, edition: edition, quantity: 1)
      future.tasks.first.update!(due_on: Date.current + 5)

      ordered = Deal.filter_by(
        workspace.deals.where(id: [overdue.id, future.id]),
        product_id: product.id, edition_id: edition.id,
        first_contact_from: "2026-01-01", first_contact_to: "2026-02-01"
      ).sorted_by_next_task(:asc)

      expect(ordered.pluck(:id)).to eq([overdue.id, future.id])
    end
  end

  it "reorders within a stage when position is given" do
    stage = pipeline.first_stage
    first = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "First", position: 0)
    second = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Second", position: 1)
    third = create_deal!(workspace, pipeline: pipeline, stage: stage, name: "Third", position: 2)

    third.move_to_stage!(stage, position: 0)

    ordered = workspace.deals.by_stage(stage.id).pluck(:name)
    expect(ordered).to eq(["Third", "First", "Second"])
    expect(third.reload.position).to eq(0)
    expect(first.reload.position).to eq(1)
    expect(second.reload.position).to eq(2)
  end

  it "moves to a stage in another pipeline by id and logs pipeline_changed" do
    other = workspace.pipelines.create!(name: "Partners", position: 1,
      pipeline_stages: [PipelineStage.new(name: "New lead", color: "hoki", probability: 5, position: 0, workspace: workspace)])
    target_stage = other.first_stage

    expect { deal.move_to_stage!(target_stage.id) }
      .to change { deal.reload.pipeline }.from(pipeline).to(other)
    expect(deal.pipeline_stage).to eq(target_stage)
    expect(deal.activities.where(action: "pipeline_changed").last.metadata).to include("to" => "Partners")
  end

  it "does not move to a same-named stage in another pipeline when using the stage name" do
    pipeline.duplicate(name: "Partners").tap(&:save!)
    qualified = pipeline.pipeline_stages.find_by!(name: "Qualified")
    deal.move_to_stage!(qualified)

    expect { deal.move_to_stage!("Qualified") }.not_to change { deal.reload.pipeline_id }
  end

  it "moves to another pipeline landing on its initial stage" do
    other = workspace.pipelines.create!(name: "Partners", position: 1,
      pipeline_stages: [PipelineStage.new(name: "New lead", color: "hoki", probability: 5, position: 0, workspace: workspace)])
    deal.move_to_stage!(pipeline.pipeline_stages.find_by(name: "Proposal").id)

    expect { deal.move_to_pipeline!(other) }.to change { deal.reload.pipeline }.from(pipeline).to(other)
    expect(deal.pipeline_stage).to eq(other.first_stage)
    expect(deal.activities.where(action: "pipeline_changed").last.metadata).to include("to" => "Partners")
  end

  it "is a no-op when moving to the same pipeline" do
    expect { deal.move_to_pipeline!(pipeline) }.not_to change { deal.reload.pipeline_stage_id }
  end

  it "finds deals by their company name, not only the deal name" do
    acme = create_company!(workspace, name: "Globex Corporation")
    match = create_deal!(workspace, pipeline: pipeline, company: acme, name: "Q3 renewal")
    other = create_deal!(workspace, pipeline: pipeline, name: "Unrelated deal")

    results = workspace.deals.search("globex")
    expect(results).to include(match)
    expect(results).not_to include(other)
  end

  it "finds deals by invoice number" do
    match = create_deal!(workspace, pipeline: pipeline, name: "Annual plan", invoice_number: "FAC-2026-042")
    other = create_deal!(workspace, pipeline: pipeline, name: "Other deal")

    results = workspace.deals.search("FAC-2026-042")
    expect(results).to include(match)
    expect(results).not_to include(other)
  end

  it "scopes open and won deals" do
    open_deal = deal
    won_deal = create_deal!(workspace, pipeline: pipeline, stage: pipeline.pipeline_stages.find_by(name: "Won"))

    expect(workspace.deals.open_deals).to include(open_deal)
    expect(workspace.deals.open_deals).not_to include(won_deal)
    expect(workspace.deals.won).to contain_exactly(won_deal)
  end

  describe "#next_pending_task" do
    it "returns the earliest pending task by due date" do
      actor = workspace.users.first
      deal.tasks.first.update!(title: "Later", due_on: Date.current + 5)
      deal.tasks.create!(title: "Sooner", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)
      deal.tasks.create!(title: "No due", workspace: workspace, user: actor, assignee: actor)

      expect(deal.next_pending_task.title).to eq("Sooner")
    end
  end

  describe ".filter_by" do
    let(:company) { create_company!(workspace) }
    let(:lead_stage) { pipeline.pipeline_stages.find_by!(name: "Lead") }
    let(:qualified_stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }
    let(:product_a) { workspace.products.create!(name: "Plan A", price: 100) }
    let(:product_b) { workspace.products.create!(name: "Plan B", price: 200) }
    let(:edition_2025) { product_a.editions.create!(name: "2025") }
    let(:edition_2026) { product_a.editions.create!(name: "2026") }

    def deal_with_line(name:, stage: lead_stage, product: product_a, edition: edition_2025, contact_date: Date.new(2026, 1, 15))
      line_edition = (edition&.product_id == product.id) ? edition : product.editions.find_or_create_by!(name: edition&.name || "2025")
      contact = create_person!(workspace, company: company, first_contact_on: contact_date)
      deal = create_deal!(workspace, pipeline: pipeline, stage: stage, name: name, company: company, contacts: [contact])
      deal.deal_products.create!(product: product, edition: line_edition, quantity: 1)
      deal
    end

    let!(:matching) { deal_with_line(name: "Matching deal") }
    let!(:other_stage) { deal_with_line(name: "Other stage deal", stage: qualified_stage) }
    let!(:other_product) { deal_with_line(name: "Other product deal", product: product_b) }
    let!(:other_edition) { deal_with_line(name: "Other edition deal", edition: edition_2026) }
    let!(:other_date) { deal_with_line(name: "Other date deal", contact_date: Date.new(2026, 3, 1)) }

    it "filters by stage" do
      results = described_class.filter_by(workspace.deals, stage: lead_stage.id)

      expect(results).to include(matching, other_product, other_edition, other_date)
      expect(results).not_to include(other_stage)
    end

    it "filters by product" do
      results = described_class.filter_by(workspace.deals, product_id: product_a.id)

      expect(results).to include(matching, other_stage, other_edition, other_date)
      expect(results).not_to include(other_product)
    end

    it "filters by edition" do
      results = described_class.filter_by(workspace.deals, edition_id: edition_2025.id)

      expect(results).to include(matching, other_stage, other_date)
      expect(results).not_to include(other_product, other_edition)
    end

    it "filters by first contact date range" do
      results = described_class.filter_by(workspace.deals,
        first_contact_from: Date.new(2026, 1, 1),
        first_contact_to: Date.new(2026, 2, 1))

      expect(results).to include(matching, other_stage, other_product, other_edition)
      expect(results).not_to include(other_date)
    end

    it "combines product and edition on the same line item" do
      results = described_class.filter_by(workspace.deals, product_id: product_a.id, edition_id: edition_2026.id)

      expect(results).to contain_exactly(other_edition)
    end

    it "combines multiple filters" do
      results = described_class.filter_by(workspace.deals,
        stage: lead_stage.id,
        product_id: product_a.id,
        edition_id: edition_2025.id,
        first_contact_from: Date.new(2026, 1, 1),
        first_contact_to: Date.new(2026, 2, 1))

      expect(results).to contain_exactly(matching)
    end
  end

  describe "relational constraints" do
    let(:actor) { workspace.users.first }
    let(:company) { create_company!(workspace) }

    it "requires a company and a future task on create" do
      invalid = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage)
      expect(invalid).not_to be_valid
      expect(invalid.errors[:company]).to be_present
      expect(invalid.errors[:base].join).to match(/siguiente acción|next action/)
    end

    it "allows a deal with only a company and a future task" do
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company,
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).to be_valid
    end

    it "rejects a contact from another company" do
      outsider = create_person!(workspace, company: create_company!(workspace))
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, contacts: [outsider],
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).not_to be_valid
      expect(deal.errors[:base].join).to match(/pertenecer|must belong/)
    end

    it "allows a contact from the partner company when partner is set" do
      partner = create_company!(workspace, name: "Avantis Group")
      partner_contact = create_person!(workspace, company: partner, first_name: "Laura")
      deal = workspace.deals.new(name: "Asisa offer", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, partner: partner, contacts: [partner_contact],
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).to be_valid
    end

    it "allows contacts from both the client and the partner" do
      partner = create_company!(workspace, name: "Avantis Group")
      client_contact = create_person!(workspace, company: company, first_name: "Client")
      partner_contact = create_person!(workspace, company: partner, first_name: "Partner")
      deal = workspace.deals.new(name: "Mixed contacts", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, partner: partner, contacts: [client_contact, partner_contact],
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).to be_valid
    end

    it "rejects a contact from a company that is neither client nor partner" do
      partner = create_company!(workspace, name: "Avantis Group")
      outsider = create_person!(workspace, company: create_company!(workspace, name: "Other Co"))
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, partner: partner, contacts: [outsider],
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).not_to be_valid
      expect(deal.errors[:base].join).to match(/pertenecer|must belong/)
    end

    it "rejects the partner being the same as the client company" do
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, partner: company,
        tasks: [Task.new(title: "t", due_on: Date.current + 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).not_to be_valid
      expect(deal.errors[:partner].join).to match(/distinta de la empresa cliente|different from the client company/)
    end

    it "allows a next action due today" do
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company,
        tasks: [Task.new(title: "t", due_on: Date.current, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).to be_valid
    end

    it "rejects a past-due task as the next action" do
      deal = workspace.deals.new(name: "X", pipeline: pipeline, pipeline_stage: pipeline.first_stage,
        company: company, contacts: [create_person!(workspace, company: company)],
        tasks: [Task.new(title: "t", due_on: Date.current - 1, workspace: workspace, user: actor, assignee: actor)])
      expect(deal).not_to be_valid
      expect(deal.errors[:base].join).to match(/siguiente acción|next action/)
    end
  end

  describe "execution duration" do
    it "is optional and must be a positive integer when set" do
      deal.execution_duration_days = nil
      expect(deal).to be_valid

      deal.execution_duration_days = 0
      expect(deal).not_to be_valid

      deal.execution_duration_days = 45
      expect(deal).to be_valid
    end
  end

  describe "execution dates and payment" do
    it "rejects an execution end date before the start date" do
      deal.execution_starts_on = Date.new(2026, 6, 1)
      deal.execution_ends_on = Date.new(2026, 5, 31)

      expect(deal).not_to be_valid
      expect(deal.errors[:execution_ends_on]).to be_present
    end

    it "sets payment_on to execution_starts_on for cash payment" do
      deal.assign_attributes(
        execution_starts_on: Date.new(2026, 7, 1),
        payment_method: "cash",
        payment_on: Date.new(2026, 12, 1)
      )

      expect(deal).to be_valid
      expect(deal.payment_on).to eq(Date.new(2026, 7, 1))
    end

    it "clears payment_on for cash when execution start is blank" do
      deal.assign_attributes(payment_method: "cash", payment_on: Date.new(2026, 12, 1))

      expect(deal).to be_valid
      expect(deal.payment_on).to be_nil
    end

    it "keeps a custom payment date for deferred payment" do
      deal.assign_attributes(
        execution_starts_on: Date.new(2026, 7, 1),
        payment_method: "deferred",
        payment_on: Date.new(2026, 12, 1)
      )

      expect(deal).to be_valid
      expect(deal.payment_on).to eq(Date.new(2026, 12, 1))
    end
  end

  describe "#duplicate" do
    let(:actor) { workspace.users.first }
    let(:company) { create_company!(workspace) }
    let(:contact) { create_person!(workspace, company: company) }
    let(:source) do
      partner = create_company!(workspace, name: "Avantis Group")
      create_deal!(workspace, pipeline: pipeline,
        name: "ACME renewal", company: company, partner: partner, contacts: [contact],
        value: 12_000, currency: "USD", probability: 60,
        expected_close_date: Date.current + 30, execution_duration_days: 90,
        execution_starts_on: Date.new(2026, 8, 1), execution_ends_on: Date.new(2026, 10, 31),
        payment_method: "deferred", payment_on: Date.new(2026, 9, 15), owner: actor)
    end

    before do
      source.update!(invoice_number: "FAC-2026-001")
      source.tasks.create!(title: "Pending follow-up", due_on: Date.current - 2,
        workspace: workspace, user: actor, assignee: actor)
      source.tasks.create!(title: "Done task", due_on: Date.current + 5, completed_at: Time.current,
        workspace: workspace, user: actor, assignee: actor)
      field = workspace.custom_fields.create!(record_type: "Deal", name: "Segment", field_type: "text")
      source.update!(custom_fields: {field.key => "Enterprise"})
      product = workspace.products.create!(name: "Plan Pro", price: 500)
      source.deal_products.create!(product: product, quantity: 2)
    end

    it "copies scalar fields, contacts, custom fields and pending tasks but not products" do
      copy = source.duplicate
      expect(copy).to be_new_record
      expect(copy.name).to eq("ACME renewal (copia)")
      expect(copy.company).to eq(company)
      expect(copy.partner).to eq(source.partner)
      expect(copy.pipeline).to eq(source.pipeline)
      expect(copy.pipeline_stage).to eq(source.pipeline_stage)
      expect(copy.value).to eq(source.value)
      expect(copy.currency).to eq("USD")
      expect(copy.probability).to eq(60)
      expect(copy.expected_close_date).to eq(Date.current + 30)
      expect(copy.execution_duration_days).to eq(90)
      expect(copy.execution_starts_on).to eq(Date.new(2026, 8, 1))
      expect(copy.execution_ends_on).to eq(Date.new(2026, 10, 31))
      expect(copy.payment_method).to eq("deferred")
      expect(copy.payment_on).to eq(Date.new(2026, 9, 15))
      expect(copy.owner).to eq(actor)
      expect(copy.invoice_number).to be_nil
      expect(copy.contact_ids).to eq(source.contact_ids)
      expect(copy.tasks.map(&:title)).to contain_exactly("Next action", "Pending follow-up")
      expect(copy.deal_products).to be_empty

      expect(copy.save).to be(true)
      expect(copy.reload.custom_fields_hash.values).to include("Enterprise")
      expect(copy.deal_products).to be_empty
    end

    it "saves without a future-dated task when duplicating" do
      copy = source.duplicate
      copy.tasks.each { |t| t.due_on = Date.current - 1 }

      expect(copy.save).to be(true)
    end
  end

  describe "destroy" do
    it "does not destroy linked people or leave contact-removed activities" do
      contact = deal.contacts.first
      expect(contact).to be_present
      product = workspace.products.create!(name: "Plan Pro", price: 100)
      deal.deal_products.create!(product: product, quantity: 1)

      expect { deal.destroy! }.to change(Deal, :count).by(-1)

      expect(Person.find_by(id: contact.id)).to eq(contact)
      expect(workspace.activities.where(action: "contacts_changed", subject_type: "Deal")).to be_empty
      expect(workspace.activities.where(action: "products_changed", subject_type: "Deal")).to be_empty
    end

    it "still logs when a contact is unlinked from a living deal" do
      contact = deal.contacts.first

      expect {
        deal.deal_contacts.find_by!(person: contact).destroy!
      }.to change { deal.activities.where(action: "contacts_changed").count }.by(1)

      expect(Person.find_by(id: contact.id)).to eq(contact)
      expect(deal.activities.where(action: "contacts_changed").last.metadata["change"]).to eq("removed")
    end
  end
end
