require "rails_helper"

RSpec.describe "Companies merge", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    sign_in_as(member)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  describe "GET /companies/duplicates" do
    it "lists duplicate groups by similar name" do
      create_company!(workspace, name: "Mapfre")
      create_company!(workspace, name: "Mapfre España")

      get duplicates_companies_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mapfre")
      expect(response.body).to include("Mapfre España")
      expect(response.body).to include("Similar name")
    end
  end

  describe "GET /companies/:id/merge" do
    it "renders the merge form with preselected secondary ids" do
      primary = create_company!(workspace, name: "Mapfre")
      secondary = create_company!(workspace, name: "Mapfre España")

      get merge_company_path(primary, secondary_ids: [secondary.id])

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mapfre")
      expect(response.body).to include("Mapfre España")
    end
  end

  describe "POST /companies/:id/merge" do
    it "merges selected companies into the primary and redirects" do
      primary = create_company!(workspace, name: "Mapfre")
      secondary = create_company!(workspace, name: "Mapfre España")
      person = create_person!(workspace, company: secondary, email: "pat@mapfre.com")

      expect {
        post merge_company_path(primary), params: {secondary_ids: [secondary.id]}
      }.to change(Company, :count).by(-1)

      expect(response).to redirect_to(company_path(primary))
      follow_redirect!
      expect(response.body).to include(I18n.t("flashes.companies.merged", count: 1, name: primary.name))
      expect(Company.exists?(secondary.id)).to be(false)
      expect(person.reload.company).to eq(primary)
    end

    it "rejects merging without selected companies" do
      primary = create_company!(workspace, name: "Mapfre")

      post merge_company_path(primary), params: {secondary_ids: []}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include(I18n.t("companies.merge.errors.no_secondaries"))
    end

    it "ignores secondary ids that are not suggested duplicates" do
      primary = create_company!(workspace, name: "Mapfre")
      unrelated = create_company!(workspace, name: "Unrelated Corp")

      post merge_company_path(primary), params: {secondary_ids: [unrelated.id]}

      expect(response).to have_http_status(:unprocessable_content)
      expect(Company.exists?(unrelated.id)).to be(true)
    end
  end
end
