require "rails_helper"

RSpec.describe "Api::V1::DealNotes", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

  describe "POST /api/v1/deals/:deal_id/notes" do
    it "creates a note on an existing deal" do
      expect {
        post "/api/v1/deals/#{deal.id}/notes",
          params: { note: { title: "Follow-up", body: "Call next week" } },
          headers: headers
      }.to change(Note, :count).by(1)

      note = deal.notes.order(:id).last
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "id" => note.id,
        "title" => "Follow-up",
        "body" => "Call next week",
        "created_at" => note.created_at.iso8601,
        "updated_at" => note.updated_at.iso8601
      )
      expect(deal.activities.where(action: "note_added").count).to eq(1)
    end

    it "returns validation errors for an invalid note" do
      expect {
        post "/api/v1/deals/#{deal.id}/notes",
          params: { note: { body: "" } },
          headers: headers
      }.not_to change(Note, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to include(blank_error_for(Note, :body))
    end

    it "does not allow adding notes to a deal from another workspace" do
      foreign_deal = create_deal!(workspaces(:two))

      expect {
        post "/api/v1/deals/#{foreign_deal.id}/notes",
          params: { note: { body: "Nope" } },
          headers: headers
      }.not_to change(Note, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
