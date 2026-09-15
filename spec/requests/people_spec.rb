require "rails_helper"

RSpec.describe "People", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  describe "GET /people.json (inline-select autocomplete)" do
    it "returns all matching people, not just the first page" do
      sign_in_as(member)
      company = create_company!(workspace)
      55.times { create_person!(workspace, company: company) }

      get people_path(format: :json)

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload.size).to eq(workspace.people.count)
      expect(payload.size).to be > 50
      expect(payload.first.keys).to contain_exactly("id", "name", "hint")
    end
  end

  describe "GET /people (HTML pagination)" do
    it "paginates the index at 50 per page" do
      sign_in_as(member)
      company = create_company!(workspace)
      51.times { create_person!(workspace, company: company) }

      get people_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 1 de 2")
    end
  end

  describe "GET /people (owner filter)" do
    it "filters people by owner" do
      sign_in_as(member)
      company = create_company!(workspace)
      owned = create_person!(workspace, company: company, first_name: "OwnedByMe", owner: member)
      create_person!(workspace, company: company, first_name: "OwnedByOther", owner: users(:two))

      get people_path(owner_id: member.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("OwnedByMe")
      expect(response.body).not_to include("OwnedByOther")
      expect(response.body).to include(owned.display_name)
    end

    it "filters unassigned people with owner_id=none" do
      sign_in_as(member)
      company = create_company!(workspace)
      unassigned = create_person!(workspace, company: company, first_name: "NoOwner", owner: nil)
      create_person!(workspace, company: company, first_name: "HasOwner", owner: member)

      get people_path(owner_id: ListFilters::NONE)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unassigned.display_name)
      expect(response.body).not_to include("HasOwner")
    end

    it "filters people by created_at range" do
      sign_in_as(member)
      company = create_company!(workspace)
      recent = create_person!(workspace, company: company, first_name: "Recent")
      recent.update_column(:created_at, Time.zone.local(2025, 6, 10, 12))
      old = create_person!(workspace, company: company, first_name: "Old")
      old.update_column(:created_at, Time.zone.local(2025, 1, 10, 12))

      get people_path(created_from: "2025-06-01", created_to: "2025-06-30")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recent")
      expect(response.body).not_to include("Old")
    end
  end

  describe "GET /people (inline edit cells)" do
    it "marks Company and Owner cells as inline-editable" do
      sign_in_as(member)
      company = create_company!(workspace, name: "Inline Co")
      person = create_person!(workspace, company: company, first_name: "Inline", owner: member)

      get people_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("person_#{person.id}_company_id")
      expect(response.body).to include("person_#{person.id}_owner_id")
      expect(response.body).to include('data-controller="inline-edit"')
      expect(response.body).to include("dblclick->inline-edit#edit")
    end
  end

  describe "PATCH /people/:id (inline edit)" do
    let(:turbo_headers) { {"Accept" => "text/vnd.turbo-stream.html"} }

    before do
      allow(WebhookDeliveryJob).to receive(:perform_later)
      allow(AutomationJob).to receive(:perform_later)
    end

    it "updates company via turbo stream" do
      sign_in_as(member)
      company = create_company!(workspace, name: "Old Co")
      other = create_company!(workspace, name: "New Co")
      person = create_person!(workspace, company: company, first_name: "Pat")

      patch person_path(person),
        params: {inline_edit: "company_id", person: {company_id: other.id}},
        headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="person_#{person.id}_company_id"))
      expect(response.body).to include("New Co")
      expect(person.reload.company).to eq(other)
    end

    it "updates owner via turbo stream" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, owner: member)
      teammate = users(:two)

      patch person_path(person),
        params: {inline_edit: "owner_id", person: {owner_id: teammate.id}},
        headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(turbo-stream action="replace" target="person_#{person.id}_owner_id"))
      expect(person.reload.owner).to eq(teammate)
    end

    it "allows clearing the owner (Unassigned)" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, owner: member)

      patch person_path(person),
        params: {inline_edit: "owner_id", person: {owner_id: ""}},
        headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(person.reload.owner).to be_nil
      expect(response.body).to include("Unassigned")
    end

    it "rejects a company from another workspace" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company)
      foreign = create_company!(workspaces(:two), name: "Foreign Co")

      expect {
        patch person_path(person),
          params: {inline_edit: "company_id", person: {company_id: foreign.id}},
          headers: turbo_headers
      }.not_to change { person.reload.company_id }

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an owner who is not a workspace member" do
      sign_in_as(member)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, owner: member)
      outsider = users(:outsider)

      expect {
        patch person_path(person),
          params: {inline_edit: "owner_id", person: {owner_id: outsider.id}},
          headers: turbo_headers
      }.not_to change { person.reload.owner_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /people/:id" do
    it "shows quick deal dialog with Add deal button" do
      sign_in_as(member)
      default = Pipeline.create_default!(workspace)
      other = default.duplicate(name: "Partners").tap(&:save!)
      memberships(:one_one).update!(current_pipeline: other)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company)
      workspace.products.create!(name: "Plan A", price: 100)

      get person_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("records.add_deal"))
      expect(response.body).to include(I18n.t("people.quick_deal.title"))
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(person, :quick_deal_form))
      expect(response.body).to include('selected="selected" value="' + other.id.to_s + '"')
      expect(response.body).to include(I18n.t("people.show.deals_empty"))
    end

    describe "deal visibility" do
      let(:admin) { users(:one) }
      let(:salesperson) { users(:two) }
      let!(:pipeline) { Pipeline.create_default!(workspace) }
      let(:company) { create_company!(workspace) }
      let(:person) { create_person!(workspace, company: company) }

      def sign_in_to_workspace!(user)
        sign_in_as(user)
        patch switch_workspace_path, params: {workspace_id: workspace.id}
      end

      it "limits a salesperson to owned and shared deals" do
        create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], owner: salesperson, name: "Own person deal")
        shared_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], owner: admin, name: "Shared person deal")
        shared_deal.deal_accesses.create!(user: salesperson)
        create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], owner: admin, name: "Hidden person deal")
        sign_in_to_workspace!(salesperson)

        get person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Own person deal")
        expect(response.body).to include("Shared person deal")
        expect(response.body).not_to include("Hidden person deal")
      end

      context "when salespeople_can_view_all_deals is enabled" do
        before { workspace.update!(salespeople_can_view_all_deals: true) }

        it "allows a salesperson to see all person deals" do
          create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], owner: admin, name: "Other person deal")
          sign_in_to_workspace!(salesperson)

          get person_path(person)

          expect(response.body).to include("Other person deal")
        end
      end
    end

    describe "deals section" do
      let(:pipeline) { Pipeline.create_default!(workspace) }
      let(:company) { create_company!(workspace) }
      let(:person) { create_person!(workspace, company: company) }
      let(:product_a) { workspace.products.create!(name: "Plan Alpha", price: 100) }
      let(:product_b) { workspace.products.create!(name: "Plan Beta", price: 200) }

      before { sign_in_as(member) }

      it "lists deals ordered by created_at descending with stage and products" do
        older = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Older deal")
        newer = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Newer deal")
        older.update_column(:created_at, Time.zone.local(2025, 1, 10, 12))
        newer.update_column(:created_at, Time.zone.local(2025, 6, 10, 12))
        newer.deal_products.create!(product: product_a, quantity: 1)

        get person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Newer deal")
        expect(response.body).to include("Older deal")
        expect(response.body).to include("Plan Alpha")
        expect(response.body.index("Newer deal")).to be < response.body.index("Older deal")
      end

      it "filters deals by product when product_id is given" do
        deal_a = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Alpha deal")
        deal_b = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Beta deal")
        deal_a.deal_products.create!(product: product_a, quantity: 1)
        deal_b.deal_products.create!(product: product_b, quantity: 1)

        get person_path(person), params: {product_id: product_a.id}

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Alpha deal")
        expect(response.body).not_to include("Beta deal")
        expect(response.body).to include('name="product_id"')
      end
    end

    describe "campaign history" do
      let(:company) { create_company!(workspace) }
      let(:person) { create_person!(workspace, company: company, email: "pat@example.com") }

      def create_campaign_message!(record, campaign:, subject:, created_at: Time.current, **attrs)
        message = workspace.email_messages.create!({
          user: member,
          record: record,
          to_address: record.email,
          subject: subject,
          body: "Hello",
          campaign: campaign,
          marketing_send: true,
          status: "sent"
        }.merge(attrs))
        message.update_column(:created_at, created_at)
        message
      end

      before { sign_in_as(member) }

      it "lists the latest campaign sends with date and subject" do
        campaign = workspace.campaigns.create!(name: "Welcome series", status: "sent")
        create_campaign_message!(person, campaign: campaign, subject: "Hola desde Welcome", created_at: Time.zone.local(2026, 9, 10, 12))

        get person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("people.show.campaigns"))
        expect(response.body).to include("Welcome series")
        expect(response.body).to include("Hola desde Welcome")
        expect(response.body).to include(I18n.t("people.show.view_more"))
        expect(response.body).to include(campaign_path(campaign))
      end

      it "previews the latest five sends and keeps older ones in the full list" do
        6.times do |index|
          campaign = workspace.campaigns.create!(name: "Campaign #{index}", status: "sent")
          create_campaign_message!(
            person,
            campaign: campaign,
            subject: "Subject #{index}",
            created_at: Time.zone.local(2026, 9, 1 + index, 12)
          )
        end

        get person_path(person)

        html = Nokogiri::HTML(response.body)
        preview = html.at('[data-person-campaigns="preview"]').text
        full_list = html.at('[data-person-campaigns="full"]').text

        expect(preview).to include("Campaign 5")
        expect(preview).not_to include("Campaign 0")
        expect(full_list).to include("Campaign 0")
        expect(full_list).to include("Campaign 5")
        expect(response.body).to include(I18n.t("people.show.view_more_count", count: 6))
      end

      it "shows expanded delivery events in the full list" do
        campaign = workspace.campaigns.create!(name: "Opened blast", status: "sent")
        message = create_campaign_message!(person, campaign: campaign, subject: "Opened blast subject")
        message.email_events.create!(event_type: "open", occurred_at: Time.zone.local(2026, 9, 12, 15), payload: {})

        get person_path(person)

        full_list = Nokogiri::HTML(response.body).at('[data-person-campaigns="full"]').text
        expect(full_list).to include(I18n.t("marketing.email_events.open"))
      end

      it "omits transactional mail and sends without a campaign" do
        campaign = workspace.campaigns.create!(name: "Real campaign", status: "sent")
        create_campaign_message!(person, campaign: campaign, subject: "Real campaign subject")
        workspace.email_messages.create!(
          user: member, record: person, to_address: person.email,
          subject: "One to one", body: "Hi", marketing_send: false, status: "sent"
        )
        workspace.email_messages.create!(
          user: member, record: person, to_address: person.email,
          subject: "Journey step", body: "Hi", marketing_send: true, status: "sent"
        )

        get person_path(person)

        html = Nokogiri::HTML(response.body)
        preview = html.at('[data-person-campaigns="preview"]').text
        full_list = html.at('[data-person-campaigns="full"]').text

        expect(preview).to include("Real campaign")
        expect(preview).not_to include("One to one")
        expect(preview).not_to include("Journey step")
        expect(full_list).not_to include("One to one")
        expect(full_list).not_to include("Journey step")
      end

      it "does not show another contact's campaign sends" do
        other = create_person!(workspace, company: company, email: "other@example.com", first_name: "Other")
        own_campaign = workspace.campaigns.create!(name: "Own campaign", status: "sent")
        other_campaign = workspace.campaigns.create!(name: "Other campaign", status: "sent")
        create_campaign_message!(person, campaign: own_campaign, subject: "Own subject")
        create_campaign_message!(other, campaign: other_campaign, subject: "Other subject")

        get person_path(person)

        expect(response.body).to include("Own campaign")
        expect(response.body).not_to include("Other campaign")
      end

      it "hides the section when marketing campaigns are disabled" do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(false)

        get person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include(I18n.t("people.show.campaigns"))
      end

      it "shows campaign name without an admin link for a salesperson" do
        campaign = workspace.campaigns.create!(name: "Sales visible", status: "sent")
        create_campaign_message!(person, campaign: campaign, subject: "Sales visible subject")
        sign_out
        sign_in_as(users(:two))
        patch switch_workspace_path, params: {workspace_id: workspace.id}

        get person_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Sales visible")
        expect(response.body).not_to include(campaign_path(campaign))
      end
    end
  end

  describe "POST /people.json (inline contact creation)" do
    it "creates a person with source and first contact date" do
      sign_in_as(member)
      company = create_company!(workspace)

      expect {
        post people_path(format: :json), params: {
          person: {
            first_name: "Ana", last_name: "García", company_id: company.id,
            email: "ana@example.com", phone: "+34 600 000 000",
            source: "web_form", first_contact_on: "2026-07-01"
          }
        }, as: :json
      }.to change(Person, :count).by(1)

      expect(response).to have_http_status(:created)
      person = Person.order(:id).last
      expect(person.source).to eq("web_form")
      expect(person.first_contact_on).to eq(Date.new(2026, 7, 1))
      expect(person.email).to eq("ana@example.com")
    end

    it "requires a team member when source is team_member" do
      sign_in_as(member)
      company = create_company!(workspace)

      post people_path(format: :json), params: {
        person: {first_name: "Ana", company_id: company.id, source: "team_member"}
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include(blank_error_for(Person, :brought_by))
    end

    it "creates a person with team member source" do
      sign_in_as(member)
      company = create_company!(workspace)
      teammate = users(:two)

      expect {
        post people_path(format: :json), params: {
          person: {
            first_name: "Ana", company_id: company.id,
            source: "team_member", brought_by_id: teammate.id
          }
        }, as: :json
      }.to change(Person, :count).by(1)

      expect(response).to have_http_status(:created)
      person = Person.order(:id).last
      expect(person.source).to eq("team_member")
      expect(person.brought_by).to eq(teammate)
    end
  end
end
