require "rails_helper"

RSpec.describe "Api::V1::Products", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

  let!(:product) do
    workspace.products.create!(name: "Premium", price: 1200, description: "Annual plan", segment: "b2b")
  end
  let!(:edition) do
    product.editions.create!(name: "2026", starts_on: Date.new(2026, 1, 1), ends_on: Date.new(2026, 12, 31))
  end

  describe "GET /api/v1/products" do
    it "lists products with editions" do
      workspace.products.create!(name: "Starter", price: 300)

      get "/api/v1/products", headers: headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.map { |entry| entry["name"] }).to eq([ "Premium", "Starter" ])

      premium = body.first
      expect(premium).to include(
        "price" => 1200.0,
        "description" => "Annual plan",
        "segment" => "b2b",
        "created_at" => product.created_at.iso8601,
        "updated_at" => product.updated_at.iso8601
      )
      expect(premium["editions"]).to contain_exactly(
        include(
          "id" => edition.id,
          "name" => "2026",
          "starts_on" => "2026-01-01",
          "ends_on" => "2026-12-31"
        )
      )
    end

    it "filters by search query" do
      workspace.products.create!(name: "Starter", price: 300)

      get "/api/v1/products", params: { q: "premium" }, headers: headers

      expect(response.parsed_body.map { |entry| entry["name"] }).to eq([ "Premium" ])
    end

    it "filters by segment" do
      workspace.products.create!(name: "Consumer", price: 100, segment: "b2c")

      get "/api/v1/products", params: { segment: "b2b" }, headers: headers

      expect(response.parsed_body.map { |entry| entry["name"] }).to eq([ "Premium" ])
    end
  end

  describe "GET /api/v1/products/:id" do
    it "shows a product" do
      get "/api/v1/products/#{product.id}", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        "id" => product.id,
        "name" => "Premium",
        "price" => 1200.0
      )
      expect(response.parsed_body["editions"].sole).to include("name" => "2026")
    end

    it "returns not found for a product outside the workspace" do
      other = workspaces(:two).products.create!(name: "Other", price: 1)

      get "/api/v1/products/#{other.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
