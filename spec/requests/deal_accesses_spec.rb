require "rails_helper"

RSpec.describe "Deal accesses", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:director) { users(:three) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Shared deal") }

  def sign_in_to_workspace!(user)
    sign_in_as(user)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "POST /deals/:deal_id/deal_accesses" do
    it "allows the deal owner to add a collaborator" do
      sign_in_to_workspace!(admin)

      expect {
        post deal_deal_accesses_path(deal), params: { user_id: salesperson.id }
      }.to change(DealAccess, :count).by(1)

      expect(response).to redirect_to(deal_path(deal))
      expect(deal.reload.collaborators).to include(salesperson)
    end

    it "allows an admin to add a collaborator" do
      other_deal = create_deal!(workspace, pipeline: pipeline, owner: salesperson, name: "Other deal")
      sign_in_to_workspace!(admin)

      post deal_deal_accesses_path(other_deal), params: { user_id: director.id }

      expect(response).to redirect_to(deal_path(other_deal))
      expect(other_deal.reload.collaborators).to include(director)
    end

    it "allows a sales director to add a collaborator" do
      sign_in_to_workspace!(director)

      post deal_deal_accesses_path(deal), params: { user_id: salesperson.id }

      expect(response).to redirect_to(deal_path(deal))
      expect(deal.reload.collaborators).to include(salesperson)
    end

    it "forbids a salesperson who is not the owner" do
      other_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Restricted deal")
      sign_in_to_workspace!(salesperson)

      post deal_deal_accesses_path(other_deal), params: { user_id: director.id }

      expect(response).to have_http_status(:not_found)
      expect(other_deal.reload.collaborators).to be_empty
    end
  end

  describe "DELETE /deals/:deal_id/deal_accesses/:id" do
    let!(:access) { deal.deal_accesses.create!(user: salesperson) }

    it "allows the deal owner to remove a collaborator" do
      sign_in_to_workspace!(admin)

      expect {
        delete deal_deal_access_path(deal, access)
      }.to change(DealAccess, :count).by(-1)

      expect(response).to redirect_to(deal_path(deal))
    end

    it "forbids a salesperson who is not the owner" do
      sign_in_to_workspace!(salesperson)

      delete deal_deal_access_path(deal, access)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include("not authorized")
      expect(deal.reload.collaborators).to include(salesperson)
    end
  end
end
