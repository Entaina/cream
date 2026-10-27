require "rails_helper"

RSpec.describe "Api docs", type: :request do
  describe "GET /api/docs" do
    it "serves Swagger UI without authentication" do
      get "/api/docs"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("swagger-ui")
      expect(response.body).to include("/api/openapi.yaml")
    end

    it "loads external Swagger assets with subresource integrity" do
      get "/api/docs"

      doc = Nokogiri::HTML(response.body)
      external = doc.css("script[src^='https://'], link[rel='stylesheet'][href^='https://']")

      expect(external).not_to be_empty
      external.each do |node|
        expect(node["integrity"]).to start_with("sha384-")
        expect(node["crossorigin"]).to eq("anonymous")
      end
    end
  end

  describe "GET /api/openapi.yaml" do
    it "serves the OpenAPI specification" do
      get "/api/openapi.yaml"

      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/yaml")
      expect(response.body).to include("openapi: 3.1.0")
      expect(response.body).to include("/api/v1/deals/{deal_id}/emails")
    end
  end
end
