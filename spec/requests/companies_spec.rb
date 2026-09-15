require "rails_helper"

RSpec.describe "Companies", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  describe "GET /companies" do
    it "allows workspace members" do
      sign_in_as(member)

      get companies_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(company.name)
    end

    it "denies users without workspace membership" do
      sign_in_as(outsider)

      get companies_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(not_authorized_message)
    end
  end

  describe "GET /companies (filters)" do
    it "filters companies by owner" do
      sign_in_as(member)
      owned = workspace.companies.create!(name: "Owned Co", owner: member)
      workspace.companies.create!(name: "Other Co", owner: users(:two))

      get companies_path(owner_id: member.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(owned.name)
      expect(response.body).not_to include("Other Co")
    end

    it "filters unassigned companies with owner_id=none" do
      sign_in_as(member)
      unassigned = workspace.companies.create!(name: "No owner Co", owner: nil)
      workspace.companies.create!(name: "Owned Co", owner: member)

      get companies_path(owner_id: ListFilters::NONE)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(unassigned.name)
      expect(response.body).not_to include("Owned Co")
    end

    it "filters blank industries with industry=none" do
      sign_in_as(member)
      blank = workspace.companies.create!(name: "Blank industry Co", industry: nil)
      workspace.companies.create!(name: "SaaS Co", industry: "SaaS")

      get companies_path(industry: ListFilters::NONE)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(blank.name)
      expect(response.body).not_to include("SaaS Co")
    end

    it "filters companies by created_at range" do
      sign_in_as(member)
      recent = workspace.companies.create!(name: "Recent Co")
      recent.update_column(:created_at, Time.zone.local(2025, 6, 10, 12))
      old = workspace.companies.create!(name: "Old Co")
      old.update_column(:created_at, Time.zone.local(2025, 1, 10, 12))

      get companies_path(created_from: "2025-06-01", created_to: "2025-06-30")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Recent Co")
      expect(response.body).not_to include("Old Co")
    end
  end

  describe "GET /companies/:id" do
    it "denies users without workspace membership" do
      sign_in_as(outsider)

      get company_path(company)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq(not_authorized_message)
    end

    it "shows fiscal information when present" do
      company.update!(fiscal_information: "CIF B12345678\nCalle Mayor 1, Zaragoza")
      sign_in_as(member)

      get company_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("companies.show.fiscal"))
      expect(response.body).to include("CIF B12345678")
    end

    it "shows fiscal information section when empty" do
      company.update!(fiscal_information: nil)
      sign_in_as(member)

      get company_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("companies.show.fiscal"))
    end

    describe "deal visibility" do
      let(:admin) { users(:one) }
      let(:salesperson) { users(:two) }
      let!(:pipeline) { Pipeline.create_default!(workspace) }

      def sign_in_to_workspace!(user)
        sign_in_as(user)
        patch switch_workspace_path, params: {workspace_id: workspace.id}
      end

      it "limits a salesperson to owned and shared deals" do
        company = create_company!(workspace)
        create_deal!(workspace, pipeline: pipeline, company: company, owner: salesperson, name: "Own company deal")
        shared_deal = create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Shared company deal")
        shared_deal.deal_accesses.create!(user: salesperson)
        create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Hidden company deal")
        sign_in_to_workspace!(salesperson)

        get company_path(company)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Own company deal")
        expect(response.body).to include("Shared company deal")
        expect(response.body).not_to include("Hidden company deal")
      end

      context "when salespeople_can_view_all_deals is enabled" do
        before { workspace.update!(salespeople_can_view_all_deals: true) }

        it "allows a salesperson to see all company deals" do
          company = create_company!(workspace)
          create_deal!(workspace, pipeline: pipeline, company: company, owner: admin, name: "Other company deal")
          sign_in_to_workspace!(salesperson)

          get company_path(company)

          expect(response.body).to include("Other company deal")
        end
      end
    end
  end

  describe "PATCH /companies/:id" do
    it "updates the fiscal information" do
      sign_in_as(member)

      patch company_path(company), params: {company: {fiscal_information: "CIF B12345678"}}

      expect(response).to redirect_to(company_path(company))
      expect(company.reload.fiscal_information).to eq("CIF B12345678")
    end
  end

  describe "GET /companies/picker" do
    it "returns companies matching the query, scoped to the workspace" do
      sign_in_as(member)
      matching = create_company!(workspaces(:one), name: "Zeta Industries")
      create_company!(workspaces(:one), name: "Other Co")
      create_company!(workspaces(:two), name: "Zeta Foreign")

      get picker_companies_path(q: "Zeta"), as: :json

      body = JSON.parse(response.body)
      expect(body.map { |row| row["name"] }).to eq(["Zeta Industries"])
      expect(body.first).to include("id" => matching.id, "name" => "Zeta Industries")
    end
  end
end
