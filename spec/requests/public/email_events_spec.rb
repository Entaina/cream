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
  let!(:mailjet_connection) do
    workspace.create_mailjet_connection!(
      user: user,
      api_key: "api-key-xxxx",
      secret_key: "secret-yyyy",
      from_email: "noreply@example.com",
      webhook_token: token
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
  end

  it "rejects requests without a valid token" do
    post public_email_events_path, params: {Events: []}.to_json, headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:unauthorized)
  end

  it "accepts Mailjet-style event payloads with token" do
    payload = {
      Events: [
        {event: "open", CustomID: message.id.to_s, time: Time.current.iso8601}
      ]
    }

    expect {
      post public_email_events_path(token: token), params: payload.to_json, headers: {"CONTENT_TYPE" => "application/json"}
    }.to change(EmailEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
  end

  it "ignores events for messages in another workspace" do
    other = workspaces(:two)
    other.create_mailjet_connection!(
      user: users(:two),
      api_key: "other-api-xxxx",
      secret_key: "other-secret-yyyy",
      from_email: "other@example.com",
      webhook_token: "other-webhook-token"
    )
    payload = {
      Events: [
        {event: "open", CustomID: message.id.to_s, time: Time.current.iso8601}
      ]
    }

    expect {
      post public_email_events_path(token: "other-webhook-token"),
        params: payload.to_json,
        headers: {"CONTENT_TYPE" => "application/json"}
    }.not_to change(EmailEvent, :count)

    expect(response).to have_http_status(:ok)
  end
end
