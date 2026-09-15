require "rails_helper"

RSpec.describe "Api::V1::Pipelines", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }

  describe "GET /api/v1/pipelines" do
    it "lists pipelines with ordered stages" do
      partners = workspace.pipelines.create!(name: "Partners", position: 1,
        pipeline_stages: [PipelineStage.new(name: "Lead", position: 0, workspace: workspace)])

      get "/api/v1/pipelines", headers: headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body.map { |entry| entry["id"] }).to eq([pipeline.id, partners.id])

      sales = body.first
      expect(sales).to include(
        "name" => "Ventas",
        "default" => true,
        "position" => 0,
        "created_at" => pipeline.created_at.iso8601,
        "updated_at" => pipeline.updated_at.iso8601
      )
      expect(sales["stages"].first).to include(
        "name" => "Lead",
        "position" => 0,
        "probability" => 10,
        "won" => false,
        "closed" => false,
        "color" => "chicago"
      )
    end
  end

  describe "GET /api/v1/pipelines/:id" do
    it "shows a pipeline" do
      get "/api/v1/pipelines/#{pipeline.id}", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        "id" => pipeline.id,
        "name" => "Ventas",
        "default" => true
      )
      expect(response.parsed_body["stages"].map { |stage| stage["name"] }).to eq(
        %w[Lead Qualified Proposal Negotiation Won Lost]
      )
    end

    it "returns not found for a pipeline outside the workspace" do
      other = Pipeline.create_default!(workspaces(:two))

      get "/api/v1/pipelines/#{other.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
