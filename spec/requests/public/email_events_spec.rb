require "rails_helper"

RSpec.describe "Public email events webhook", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "webhook@example.com") }
  let!(:message) do
    workspace.email_messages.create!(
      user: user,
      record: person,
      to_address: person.email,
      subject: "Webhook",
      body: "Hi",
      marketing_send: true
    )
  end
  let(:token) { "test-webhook-token" }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MAILJET_WEBHOOK_TOKEN").and_return(token)
  end

  it "rejects requests without a valid token" do
    post public_email_events_path, params: { Events: [] }.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts Mailjet-style event payloads with token" do
    payload = {
      Events: [
        { event: "open", CustomID: message.id.to_s, time: Time.current.iso8601 }
      ]
    }

    expect {
      post public_email_events_path(token: token), params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    }.to change(EmailEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
  end
end
