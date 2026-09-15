require "rails_helper"

RSpec.describe "SavedViews", type: :request do
  fixtures :users, :workspaces, :memberships, :companies, :custom_fields, :saved_views

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  before do
    sign_in_as(admin)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  describe "POST /saved_views" do
    it "creates a saved view from current filters" do
      expect {
        post saved_views_path, params: {
          record_type: "Person",
          q: "ann",
          company_id: company.id,
          saved_view: {name: "Acme search", shared: "0"}
        }
      }.to change(SavedView, :count).by(1)

      view = SavedView.order(:id).last
      expect(response).to redirect_to(people_path(view: view.id))
      expect(view.filters).to eq("q" => "ann", "company_id" => company.id.to_s)
      expect(view.user).to eq(admin)
    end

    it "creates a private view when shared is omitted (unchecked checkbox)" do
      expect {
        post saved_views_path, params: {
          record_type: "Person",
          company_id: company.id,
          saved_view: {name: "Delta"}
        }
      }.to change(SavedView, :count).by(1)

      view = SavedView.order(:id).last
      expect(response).to redirect_to(people_path(view: view.id))
      expect(view.shared).to be false
      expect(view.name).to eq("Delta")
    end

    it "redirects deal views to the board by default" do
      post saved_views_path, params: {
        record_type: "Deal",
        q: "alpha",
        saved_view: {name: "Board default", shared: "0"}
      }

      view = SavedView.order(:id).last
      expect(response).to redirect_to(board_deals_path(view: view.id))
      expect(view.filters).to eq("q" => "alpha")
    end

    it "redirects deal views to the table when surface=table" do
      post saved_views_path, params: {
        record_type: "Deal",
        q: "beta",
        surface: "table",
        saved_view: {name: "Table surface", shared: "0"}
      }

      view = SavedView.order(:id).last
      expect(response).to redirect_to(deals_path(view: view.id))
    end
  end

  describe "PATCH /saved_views/:id" do
    it "updates filters when requested" do
      view = saved_views(:person_gold)

      patch saved_view_path(view), params: {
        update_filters: "1",
        q: "bob",
        view: view.id
      }

      expect(response).to redirect_to(people_path(view: view.id))
      expect(view.reload.filters).to eq("q" => "bob")
    end

    it "renames a view" do
      view = saved_views(:person_gold)

      patch saved_view_path(view), params: {
        saved_view: {name: "Renamed", shared: "1"}
      }

      expect(response).to redirect_to(people_path(view: view.id))
      expect(view.reload.name).to eq("Renamed")
      expect(view.shared?).to be true
    end

    it "redirects deal updates to the board by default" do
      view = SavedView.create!(
        workspace: workspace,
        user: admin,
        record_type: "Deal",
        name: "Deal view",
        filters: {"q" => "old"}
      )

      patch saved_view_path(view), params: {
        update_filters: "1",
        q: "new",
        view: view.id
      }

      expect(response).to redirect_to(board_deals_path(view: view.id))
      expect(view.reload.filters).to eq("q" => "new")
    end

    it "redirects deal updates to the table when surface=table" do
      view = SavedView.create!(
        workspace: workspace,
        user: admin,
        record_type: "Deal",
        name: "Deal table view",
        filters: {"q" => "old"}
      )

      patch saved_view_path(view), params: {
        update_filters: "1",
        q: "new",
        surface: "table",
        view: view.id
      }

      expect(response).to redirect_to(deals_path(view: view.id))
    end

    it "forbids members from updating another user's personal view" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
      view = saved_views(:person_gold)

      patch saved_view_path(view), params: {saved_view: {name: "Blocked"}}

      expect(response).to redirect_to(root_path)
      expect(view.reload.name).to eq("Gold tier")
    end
  end

  describe "DELETE /saved_views/:id" do
    it "removes a view" do
      view = saved_views(:person_gold)

      expect {
        delete saved_view_path(view)
      }.to change(SavedView, :count).by(-1)

      expect(response).to redirect_to(people_path)
    end

    it "redirects deal deletes to the board by default" do
      view = SavedView.create!(
        workspace: workspace,
        user: admin,
        record_type: "Deal",
        name: "To delete",
        filters: {}
      )

      delete saved_view_path(view)

      expect(response).to redirect_to(board_deals_path)
    end

    it "redirects deal deletes to the table when surface=table" do
      view = SavedView.create!(
        workspace: workspace,
        user: admin,
        record_type: "Deal",
        name: "Table delete",
        filters: {}
      )

      delete saved_view_path(view), params: {surface: "table"}

      expect(response).to redirect_to(deals_path)
    end
  end

  describe "GET /people?view=:id" do
    it "applies the saved view filters" do
      gold = create_person!(workspace, company: company, first_name: "Goldie")
      gold.update!(custom_fields: {"customer_tier" => "Gold"})
      silver = create_person!(workspace, company: company, first_name: "Silvia")
      silver.update!(custom_fields: {"customer_tier" => "Silver"})
      view = saved_views(:person_gold)

      get people_path(view: view.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Goldie")
      expect(response.body).not_to include("Silvia")
      expect(response.body).to include("Gold tier")
    end

    it "shows shared views to other members" do
      sign_in_as(member)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
      view = saved_views(:person_shared)

      get people_path(view: view.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("All at Acme")
    end
  end
end
