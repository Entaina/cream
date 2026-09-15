require "rails_helper"

RSpec.describe "Public Beehiiv webhooks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:publication) { create_beehiiv_publication!(workspace) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "imports subscription.created events" do
    payload = {
      event_type: "subscription.created",
      data: {
        id: "sub_webhook",
        email: "webhook@example.com",
        status: "active"
      }
    }.to_json

    post public_beehiiv_webhook_path(token: publication.webhook_token),
      params: payload,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:ok)

    person = Person.find_by_email(workspace, "webhook@example.com")
    expect(person).to be_present
    newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
    expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter).status).to eq("subscribed")
  end

  it "rejects unknown tokens" do
    post public_beehiiv_webhook_path(token: "unknown"),
      params: {event_type: "subscription.created", data: {}}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:unauthorized)
  end
end
