require "rails_helper"

RSpec.describe "Products", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:outsider) { users(:outsider) }

  describe "GET /products" do
    it "lists products for workspace members" do
      sign_in_as(member)
      workspaces(:one).products.create!(name: "Plan Pro", price: 1200)

      get products_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Plan Pro")
    end

    it "denies users without workspace membership" do
      sign_in_as(outsider)
      get products_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /products" do
    it "creates a product in the current workspace" do
      sign_in_as(member)

      expect {
        post products_path, params: { product: { name: "Onboarding", price: 2500, segment: "b2b" } }
      }.to change(workspaces(:one).products, :count).by(1)

      expect(response).to redirect_to(products_path)
      expect(workspaces(:one).products.find_by(name: "Onboarding").segment).to eq("b2b")
    end
  end

  describe "GET /products with segment filter" do
    it "filters products by segment" do
      sign_in_as(member)
      workspaces(:one).products.create!(name: "Enterprise", price: 1000, segment: "b2b")
      workspaces(:one).products.create!(name: "Consumer", price: 500, segment: "b2c")

      get products_path, params: { segment: "b2b" }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Enterprise")
      expect(response.body).not_to include("Consumer")
    end
  end
end
