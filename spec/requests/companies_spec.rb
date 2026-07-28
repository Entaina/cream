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
      expect(flash[:alert]).to include("not authorized")
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
      expect(flash[:alert]).to include("not authorized")
    end

    it "shows fiscal information when present" do
      company.update!(fiscal_information: "CIF B12345678\nCalle Mayor 1, Zaragoza")
      sign_in_as(member)

      get company_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fiscal information")
      expect(response.body).to include("CIF B12345678")
    end

    it "shows fiscal information section when empty" do
      company.update!(fiscal_information: nil)
      sign_in_as(member)

      get company_path(company)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fiscal information")
    end
  end

  describe "PATCH /companies/:id" do
    it "updates the fiscal information" do
      sign_in_as(member)

      patch company_path(company), params: { company: { fiscal_information: "CIF B12345678" } }

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
      expect(body.map { |row| row["name"] }).to eq([ "Zeta Industries" ])
      expect(body.first).to include("id" => matching.id, "name" => "Zeta Industries")
    end
  end
end
