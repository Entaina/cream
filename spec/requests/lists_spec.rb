require "rails_helper"

RSpec.describe "Lists", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let!(:list) { workspace.lists.create!(name: "Deal targets", record_type: "Deal") }

  def sign_in_to_workspace!(user)
    sign_in_as(user)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /lists/:id for Deal lists" do
    it "limits candidates and visible entries to deals the salesperson can access" do
      own_deal = create_deal!(workspace, pipeline: pipeline, owner: salesperson, name: "Own list deal")
      hidden_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Hidden list deal")
      list.list_entries.create!(record: own_deal)
      list.list_entries.create!(record: hidden_deal)

      sign_in_to_workspace!(salesperson)
      get list_path(list)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Own list deal")
      expect(response.body).not_to include("Hidden list deal")
      expect(response.body).not_to include(%(<option value="#{hidden_deal.id}">Hidden list deal</option>))
    end

    it "shows all deal entries and candidates when view-all is enabled" do
      workspace.update!(salespeople_can_view_all_deals: true)
      listed_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Visible list deal")
      candidate_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Visible candidate deal")
      list.list_entries.create!(record: listed_deal)

      sign_in_to_workspace!(salesperson)
      get list_path(list)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible list deal")
      expect(response.body).to include(%(<option value="#{candidate_deal.id}">Visible candidate deal</option>))
      expect(response.body).not_to include(%(<option value="#{listed_deal.id}">Visible list deal</option>))
    end
  end

  describe "POST /lists/:list_id/entries" do
    it "forbids adding a deal the salesperson cannot access" do
      hidden_deal = create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Hidden add deal")
      sign_in_to_workspace!(salesperson)

      expect {
        post list_entries_path(list), params: { record_id: hidden_deal.id }
      }.not_to change(ListEntry, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
