require "rails_helper"

RSpec.describe "Api::V1::Deals", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

  describe "PATCH /api/v1/deals/:id" do
    it "routes stage changes through move_to_stage! so activity and hooks fire" do
      target = pipeline.pipeline_stages.find_by(name: "Won")

      expect {
        patch "/api/v1/deals/#{deal.id}", params: { deal: { pipeline_stage_id: target.id } }, headers: headers
      }.to change { deal.activities.where(action: "stage_changed").count }.by(1)

      expect(response).to have_http_status(:success)
      expect(deal.reload.stage_label).to eq("Won")
    end

    it "updates plain fields without logging a stage change" do
      expect {
        patch "/api/v1/deals/#{deal.id}", params: { deal: { name: "Via API" } }, headers: headers
      }.not_to change { deal.activities.where(action: "stage_changed").count }

      expect(deal.reload.name).to eq("Via API")
      expect(response.parsed_body).to include(
        "created_at" => deal.created_at.iso8601,
        "updated_at" => deal.updated_at.iso8601
      )
    end
  end
end
