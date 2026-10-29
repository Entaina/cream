require "rails_helper"

RSpec.describe "Public Beehiiv webhooks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:signing_secret) { "whsec_#{Base64.strict_encode64("beehiiv-test-signing-secret")}" }
  let!(:publication) { create_beehiiv_publication!(workspace, webhook_signing_secret: signing_secret) }
  let(:payload) do
    {
      event_type: "subscription.created",
      data: {
        id: "sub_webhook",
        email: "webhook@example.com",
        status: "active"
      }
    }.to_json
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  def svix_headers(body, secret: signing_secret)
    msg_id = "msg_test"
    timestamp = Time.now.to_i.to_s
    key = Base64.decode64(secret.delete_prefix("whsec_"))
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", key, "#{msg_id}.#{timestamp}.#{body}"))
    {
      "CONTENT_TYPE" => "application/json",
      "svix-id" => msg_id,
      "svix-timestamp" => timestamp,
      "svix-signature" => "v1,#{signature}"
    }
  end

  it "imports subscription.created events with a valid signature" do
    post public_beehiiv_webhook_path(token: publication.webhook_token),
      params: payload,
      headers: svix_headers(payload)

    expect(response).to have_http_status(:ok)

    person = Person.find_by_email(workspace, "webhook@example.com")
    expect(person).to be_present
    newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
    expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter).status).to eq("subscribed")
  end

  context "with forgery protection enabled, as in production" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    before { allow(BeehiivPushJob).to receive(:perform_later) }

    it "accepts signed webhooks, which carry no CSRF token" do
      post public_beehiiv_webhook_path(token: publication.webhook_token),
        params: payload,
        headers: svix_headers(payload)

      expect(response).to have_http_status(:ok)
      expect(Person.find_by_email(workspace, "webhook@example.com")).to be_present
    end
  end

  it "rejects an invalid signature" do
    post public_beehiiv_webhook_path(token: publication.webhook_token),
      params: payload,
      headers: svix_headers(payload, secret: "whsec_#{Base64.strict_encode64("another-secret")}")

    expect(response).to have_http_status(:unauthorized)
    expect(Person.find_by_email(workspace, "webhook@example.com")).to be_nil
  end

  it "rejects webhooks for publications without a signing secret" do
    publication.update!(webhook_signing_secret: nil)

    post public_beehiiv_webhook_path(token: publication.webhook_token),
      params: payload,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:unauthorized)
    expect(Person.find_by_email(workspace, "webhook@example.com")).to be_nil
  end

  it "rejects unknown tokens" do
    post public_beehiiv_webhook_path(token: "unknown"),
      params: {event_type: "subscription.created", data: {}}.to_json,
      headers: {"CONTENT_TYPE" => "application/json"}

    expect(response).to have_http_status(:unauthorized)
  end
end
