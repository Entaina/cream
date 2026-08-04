require "rails_helper"

RSpec.describe "Api::V1::Deals", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { create_company!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

  def valid_create_params(**extra)
    {
      deal: {
        name: "API Deal",
        company_id: company.id,
        pipeline_id: pipeline.id,
        pipeline_stage_id: pipeline.first_stage.id,
        tasks_attributes: [ { title: "Follow up", due_on: Date.current + 3 } ]
      }
    }.deep_merge(extra)
  end

  describe "POST /api/v1/deals" do
    it "creates a deal with nested notes" do
      expect {
        post "/api/v1/deals",
          params: valid_create_params(notes: [ { title: "Kickoff", body: "Met at conference" } ]),
          headers: headers
      }.to change(Deal, :count).by(1).and change(Note, :count).by(1)

      body = response.parsed_body
      created_deal = workspace.deals.find(body["id"])
      note = created_deal.notes.sole

      expect(response).to have_http_status(:created)
      expect(body["notes"]).to contain_exactly(
        include(
          "id" => note.id,
          "title" => "Kickoff",
          "body" => "Met at conference",
          "created_at" => note.created_at.iso8601,
          "updated_at" => note.updated_at.iso8601
        )
      )
      expect(created_deal.activities.where(action: "note_added").count).to eq(1)
    end

    it "rolls back the deal when a nested note is invalid" do
      expect {
        post "/api/v1/deals",
          params: valid_create_params(notes: [ { body: "" } ]),
          headers: headers
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to include("Body can't be blank")
    end
  end

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
