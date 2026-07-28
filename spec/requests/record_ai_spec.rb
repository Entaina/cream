require "rails_helper"

RSpec.describe "Record AI", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "alex@acme.test") }
  let(:client) { instance_double(Ai::Client) }

  before do
    sign_in_as(user)
    allow(Ai::Client).to receive(:new).and_return(client)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:ai_assistant).and_return(true)
  end

  describe "POST /ai/people/:id/summary" do
    it "returns a structured summary" do
      allow(client).to receive(:chat).and_return({
        summary: "Active contact",
        risks: [],
        next_steps: [ "Follow up" ],
        missing_data: []
      }.to_json)

      post record_ai_summary_path(record_type: "people", record_id: person.id), as: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["summary"]).to eq("Active contact")
    end

    it "returns 404 when the feature is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:ai_assistant).and_return(false)

      post record_ai_summary_path(record_type: "people", record_id: person.id), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /ai/people/:id/create_task" do
    it "creates a task and logs AI activity" do
      expect {
        post record_ai_create_task_path(record_type: "people", record_id: person.id),
          params: { title: "Call Alex", due_on: Date.current + 2, reason: "Suggested by AI" },
          as: :json
      }.to change { person.tasks.count }.by(1)

      expect(response).to have_http_status(:success)
      expect(person.activities.where(action: "ai_task_created")).to exist
    end
  end

  describe "POST /ai/people/:id/draft_email" do
    it "returns a draft subject and body" do
      allow(client).to receive(:chat).and_return({ subject: "Hello", body: "Checking in" }.to_json)

      post record_ai_draft_email_path(record_type: "people", record_id: person.id),
        params: { goal: "Follow up" },
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["subject"]).to eq("Hello")
      expect(body["body"]).to eq("Checking in")
    end
  end
end
