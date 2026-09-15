require "rails_helper"

RSpec.describe "Active pipeline switching", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:membership) { memberships(:one_one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }

  before { sign_in_as(member) }

  describe "PATCH /active_pipeline" do
    it "persists the selected pipeline" do
      other = pipeline.duplicate(name: "Partners").tap(&:save!)

      patch active_pipeline_path, params: {pipeline_id: other.id, return_to: board_deals_path}

      expect(response).to redirect_to(board_deals_path)
      expect(membership.reload.current_pipeline).to eq(other)
    end

    it "clears the selection when choosing all pipelines" do
      membership.update!(current_pipeline: pipeline)

      patch active_pipeline_path, params: {pipeline_id: "all", return_to: deals_path}

      expect(response).to redirect_to(deals_path)
      expect(membership.reload.current_pipeline).to be_nil
    end

    it "rejects pipelines outside the workspace" do
      outsider = workspaces(:two)
      outsider_pipeline = Pipeline.create_default!(outsider)

      patch active_pipeline_path, params: {pipeline_id: outsider_pipeline.id}

      expect(response).to have_http_status(:not_found)
    end

    it "resets deals table filters when return_to includes query params" do
      get deals_path(q: "table-search")

      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id, return_to: deals_path(q: "table-search", stage: "lead")}

      expect(response).to redirect_to(deals_path)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "deals#index")).to be_nil
    end

    it "resets deals board filters when return_to includes query params" do
      get board_deals_path(q: "board-search")

      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id, return_to: board_deals_path(q: "board-search")}

      expect(response).to redirect_to(board_deals_path)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "deals#board")).to be_nil
    end

    it "resets people filters when return_to includes query params" do
      company = create_company!(workspace)
      get people_path(q: "ana", company_id: company.id)

      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id, return_to: people_path(q: "ana", company_id: company.id)}

      expect(response).to redirect_to(people_path)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "people#index")).to be_nil
    end

    it "resets companies filters when return_to includes query params" do
      get companies_path(q: "acme", industry: "Software")

      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id, return_to: companies_path(q: "acme", industry: "Software")}

      expect(response).to redirect_to(companies_path)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "companies#index")).to be_nil
    end

    it "resets listing filters when redirecting via referer" do
      company = create_company!(workspace)
      get people_path(q: "ana", company_id: company.id)

      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id},
        headers: {"HTTP_REFERER" => people_path(q: "ana", company_id: company.id)}

      expect(response).to redirect_to(people_path)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "people#index")).to be_nil
    end

    it "preserves query params on non-listing return paths" do
      patch active_pipeline_path,
        params: {pipeline_id: pipeline.id, return_to: root_path(closed: "1")}

      expect(response).to redirect_to(root_path(closed: "1"))
    end
  end
end
