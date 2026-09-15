require "rails_helper"

RSpec.describe "People merge", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { create_company!(workspace) }

  before do
    sign_in_as(member)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  describe "GET /people/duplicates" do
    it "lists duplicate groups by email within a company" do
      create_person!(workspace, company: company, first_name: "Pat", email: "dup@acme.com")
      create_person!(workspace, company: company, first_name: "Patrick", email: "dup@acme.com")

      get duplicates_people_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("dup@acme.com")
      expect(response.body).to include("Pat")
      expect(response.body).to include("Patrick")
    end

    it "lists duplicate groups with the same email across companies" do
      other_company = create_company!(workspace, name: "Particulares")
      create_person!(workspace, company: company, first_name: "Laura Shinakho Sanz", email: "laura@viveespana.es")
      create_person!(workspace, company: other_company, first_name: "Laura Shinakho", email: "laura@viveespana.es")

      get duplicates_people_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("laura@viveespana.es")
      expect(response.body).to include("Laura Shinakho Sanz")
      expect(response.body).to include("Laura Shinakho")
    end
  end

  describe "GET /people/:id/merge" do
    it "renders the merge form with preselected secondary ids" do
      primary = create_person!(workspace, company: company, first_name: "Primary", email: "dup@acme.com")
      secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "dup@acme.com")

      get merge_person_path(primary, secondary_ids: [secondary.id])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Primary")
      expect(response.body).to include("Secondary")
    end

    it "includes same-email contacts from other companies as merge candidates" do
      other_company = create_company!(workspace, name: "Particulares")
      primary = create_person!(workspace, company: company, first_name: "Laura Shinakho Sanz", email: "laura@viveespana.es")
      create_person!(workspace, company: other_company, first_name: "Laura Shinakho", email: "laura@viveespana.es")

      get merge_person_path(primary)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Laura Shinakho")
      expect(response.body).to include("Particulares")
    end

    it "renders the contact search field" do
      primary = create_person!(workspace, company: company, first_name: "Primary", email: "dup@acme.com")

      get merge_person_path(primary)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("people.merge.search_label"))
      expect(response.body).to include('data-controller="merge-person-search"')
    end
  end

  describe "POST /people/:id/merge" do
    it "merges selected contacts into the primary and redirects" do
      primary = create_person!(workspace, company: company, first_name: "Primary", email: "dup@acme.com")
      secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "dup@acme.com")

      expect {
        post merge_person_path(primary), params: {secondary_ids: [secondary.id]}
      }.to change(Person, :count).by(-1)

      expect(response).to redirect_to(person_path(primary))
      follow_redirect!
      expect(response.body).to include("Merged 1 duplicate contact")
      expect(Person.exists?(secondary.id)).to be(false)
    end

    it "rejects merging without selected contacts" do
      primary = create_person!(workspace, company: company, email: "dup@acme.com")

      post merge_person_path(primary), params: {secondary_ids: []}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Select at least one contact to merge")
    end

    it "merges same-email contacts from another company" do
      other_company = create_company!(workspace)
      primary = create_person!(workspace, company: company, email: "dup@acme.com", first_name: "Primary")
      secondary = create_person!(workspace, company: other_company, email: "dup@acme.com", first_name: "Secondary")

      expect {
        post merge_person_path(primary), params: {secondary_ids: [secondary.id]}
      }.to change(Person, :count).by(-1)

      expect(response).to redirect_to(person_path(primary))
      expect(Person.exists?(secondary.id)).to be(false)
      expect(primary.reload.company).to eq(company)
    end

    it "merges contacts from another company when emails differ" do
      primary = create_person!(workspace, company: company, email: "dup@acme.com", first_name: "Primary")
      other_company = create_company!(workspace)
      secondary = create_person!(workspace, company: other_company, email: "other@acme.com", first_name: "Secondary")

      expect {
        post merge_person_path(primary), params: {secondary_ids: [secondary.id]}
      }.to change(Person, :count).by(-1)

      expect(response).to redirect_to(person_path(primary))
      expect(Person.exists?(secondary.id)).to be(false)
      expect(primary.reload.company).to eq(company)
    end

    it "merges a secondary with a deal and redirects" do
      primary = create_person!(workspace, company: company, first_name: "Primary", email: "dup@acme.com")
      secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "dup@acme.com")
      deal = create_deal!(workspace, company: company, contacts: [secondary])

      expect {
        post merge_person_path(primary), params: {secondary_ids: [secondary.id]}
      }.to change(Person, :count).by(-1)

      expect(response).to redirect_to(person_path(primary))
      expect(Person.exists?(secondary.id)).to be(false)
      expect(DealContact.where(deal_id: deal.id, person_id: primary.id).count).to eq(1)
    end

    it "renders merge with an alert when PersonMerger raises an ActiveRecord error" do
      primary = create_person!(workspace, company: company, email: "dup@acme.com")
      secondary = create_person!(workspace, company: company, email: "dup@acme.com")

      allow(PersonMerger).to receive(:call).and_raise(ActiveRecord::RecordInvalid.new(Person.new))

      post merge_person_path(primary), params: {secondary_ids: [secondary.id]}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Could not merge contacts")
      expect(Person.exists?(secondary.id)).to be(true)
    end
  end
end
