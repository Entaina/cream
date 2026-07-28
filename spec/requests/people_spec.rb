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
    let(:turbo_headers) { { "Accept" => "text/vnd.turbo-stream.html" } }

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
        params: { inline_edit: "company_id", person: { company_id: other.id } },
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
        params: { inline_edit: "owner_id", person: { owner_id: teammate.id } },
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
        params: { inline_edit: "owner_id", person: { owner_id: "" } },
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
          params: { inline_edit: "company_id", person: { company_id: foreign.id } },
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
          params: { inline_edit: "owner_id", person: { owner_id: outsider.id } },
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
      expect(response.body).to include("Add deal")
      expect(response.body).to include("New deal")
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(person, :quick_deal_form))
      expect(response.body).to include('selected="selected" value="' + other.id.to_s + '"')
      expect(response.body).to include("No deals yet.")
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
        person: { first_name: "Ana", company_id: company.id, source: "team_member" }
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(JSON.parse(response.body)["errors"]).to include("Brought by can't be blank")
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
