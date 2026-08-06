require "rails_helper"

RSpec.describe "List filter persistence", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  describe "GET /people" do
    it "stores filters when the index is filtered" do
      sign_in_as(member)
      company = create_company!(workspace)

      get people_path(q: "ana", company_id: company.id)

      expect(response).to have_http_status(:ok)
      stored = ListFilterState.read(
        session: Current.session,
        workspace: workspace,
        key: "people#index"
      )
      expect(stored).to include("q" => "ana", "company_id" => company.id.to_s)
    end

    it "restores stored filters when returning without query params" do
      sign_in_as(member)
      company = create_company!(workspace)

      get people_path(q: "ana", company_id: company.id)
      get people_path

      expect(response).to redirect_to(people_path(q: "ana", company_id: company.id))
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it "restores stored filters and page when returning without query params" do
      sign_in_as(member)
      company = create_company!(workspace)
      51.times { create_person!(workspace, company: company) }

      get people_path(company_id: company.id, page: 2)
      get people_path

      expect(response).to redirect_to(people_path(company_id: company.id, page: 2))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 2 de")
    end

    it "stores page when paginating with filters" do
      sign_in_as(member)
      company = create_company!(workspace)
      51.times { create_person!(workspace, company: company) }

      get people_path(company_id: company.id, page: 2)

      stored = ListFilterState.read(
        session: Current.session,
        workspace: workspace,
        key: "people#index"
      )
      expect(stored).to include("company_id" => company.id.to_s, "page" => "2")
    end

    it "merges page with stored filters when only page is present" do
      sign_in_as(member)
      company = create_company!(workspace)
      51.times { create_person!(workspace, company: company) }

      get people_path(company_id: company.id)
      get people_path(page: 2)

      expect(response).to redirect_to(people_path(company_id: company.id, page: 2))
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Página 2 de")
    end

    it "does not carry over page when filters change without page param" do
      sign_in_as(member)
      company_a = create_company!(workspace)
      company_b = create_company!(workspace)
      51.times { create_person!(workspace, company: company_a) }

      get people_path(company_id: company_a.id, page: 2)
      get people_path(company_id: company_b.id)

      stored = ListFilterState.read(
        session: Current.session,
        workspace: workspace,
        key: "people#index"
      )
      expect(stored).to eq("company_id" => company_b.id.to_s)
      expect(stored).not_to have_key("page")
    end

    it "clears stored filters with clear_filters=1" do
      sign_in_as(member)
      get people_path(q: "ana")
      get people_path(clear_filters: 1)

      expect(response).to redirect_to(people_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(ListFilterState.read(session: Current.session, workspace: workspace, key: "people#index")).to be_nil
    end

    it "does not affect JSON requests" do
      sign_in_as(member)
      get people_path(q: "ana")
      get people_path(format: :json)

      expect(response).to have_http_status(:ok)
      expect(response).not_to be_redirect
    end
  end

  describe "GET /deals and /deals/board" do
    let!(:pipeline) { Pipeline.create_default!(workspace) }

    it "keeps separate stored filters for table and board" do
      sign_in_as(member)

      get deals_path(q: "table-search")
      get board_deals_path(q: "board-search")

      table_state = ListFilterState.read(session: Current.session, workspace: workspace, key: "deals#index")
      board_state = ListFilterState.read(session: Current.session, workspace: workspace, key: "deals#board")

      expect(table_state).to include("q" => "table-search")
      expect(board_state).to include("q" => "board-search")
    end

    it "restores board filters independently" do
      sign_in_as(member)

      get board_deals_path(q: "board-search")
      get board_deals_path

      expect(response).to redirect_to(board_deals_path(q: "board-search"))
    end

    it "does not restore the closed toggle from stored board filters" do
      sign_in_as(member)

      get board_deals_path(closed: "1")
      get board_deals_path

      expect(response).to have_http_status(:ok)
      expect(response).not_to be_redirect
      stored = ListFilterState.read(session: Current.session, workspace: workspace, key: "deals#board")
      expect(stored).not_to have_key("closed")
    end
  end

  describe "GET /tasks" do
    it "restores the selected filter tab" do
      sign_in_as(member)

      get tasks_path(filter: "completed")
      get tasks_path

      expect(response).to redirect_to(tasks_path(filter: "completed"))
    end

    it "restores the selected assignee filter" do
      sign_in_as(member)

      get tasks_path(filter: "pending", assignee_id: "all")
      get tasks_path

      expect(response).to redirect_to(tasks_path(filter: "pending", assignee_id: "all"))
    end
  end

  describe "GET /products" do
    it "restores search filters" do
      sign_in_as(member)

      get products_path(q: "premium")
      get products_path

      expect(response).to redirect_to(products_path(q: "premium"))
    end
  end

  describe "workspace scoping" do
    it "stores filters under the active workspace" do
      sign_in_as(member)

      get people_path(q: "scoped-search")

      record = ListFilterState.find_by(session: Current.session, key: "people#index")
      expect(record.workspace_id).to eq(workspace.id)
      expect(record.params).to include("q" => "scoped-search")
    end
  end
end
