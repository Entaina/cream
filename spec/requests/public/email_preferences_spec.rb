require "rails_helper"

RSpec.describe "Public email preferences", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "prefs@example.com") }
  let(:token) { Marketing::PreferenceToken.generate(person: person) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  describe "GET /e/preferences/:token" do
    it "renders the preference center" do
      get public_email_preferences_path(token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Newsletter")
    end
  end

  describe "PATCH /e/preferences/:token" do
    it "updates subscriptions" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")

      patch public_email_preferences_path(token: token), params: {subscription_type_ids: [newsletter.id]}

      expect(response).to redirect_to(public_email_preferences_path(token: token))
      subscription = EmailSubscription.find_by!(person: person, subscription_type: newsletter)
      expect(subscription).to be_subscribed
    end
  end

  describe "GET /e/unsubscribe/:token" do
    before { allow(BeehiivPushJob).to receive(:perform_later) }

    it "asks for confirmation without unsubscribing, so link scanners can't unsubscribe anyone" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      Marketing::ConsentService.subscribe!(person: person, subscription_type: newsletter, source: "test", legal_basis: "consent")

      get public_email_unsubscribe_path(token: token, type: "newsletter")

      expect(response).to have_http_status(:ok)
      expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter)).to be_subscribed
      form = Nokogiri::HTML(response.body).at_css("form[method=post]")
      expect(form["action"]).to eq(public_email_unsubscribe_path(token: token, type: "newsletter"))
    end

    it "keeps the all flag in the confirmation form" do
      get public_email_unsubscribe_path(token: token, all: 1)

      form = Nokogiri::HTML(response.body).at_css("form[method=post]")
      expect(form["action"]).to eq(public_email_unsubscribe_path(token: token, all: 1))
      expect(EmailSuppression.suppressed?(workspace, person.email)).to be(false)
    end

    it "returns not found for an invalid token" do
      get public_email_unsubscribe_path(token: "invalid")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "one-click unsubscribe with forgery protection enabled, as in production" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    before { allow(BeehiivPushJob).to receive(:perform_later) }

    it "unsubscribes on the RFC 8058 POST from the mail client, which has no CSRF token or session" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      Marketing::ConsentService.subscribe!(person: person, subscription_type: newsletter, source: "test", legal_basis: "consent")

      post public_email_unsubscribe_path(token: token, type: "newsletter"),
        params: "List-Unsubscribe=One-Click",
        headers: {"CONTENT_TYPE" => "application/x-www-form-urlencoded"}

      expect(response).to have_http_status(:ok)
      expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter)).not_to be_subscribed
    end

    it "still requires the CSRF token to update preferences" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")

      patch public_email_preferences_path(token: token), params: {subscription_type_ids: [newsletter.id]}

      expect(response).to have_http_status(:unprocessable_content)
      expect(EmailSubscription.find_by(person: person, subscription_type: newsletter)).to be_nil
    end
  end

  describe "POST /e/unsubscribe/:token" do
    it "unsubscribes from the requested type without global suppression" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      Marketing::ConsentService.subscribe!(
        person: person,
        subscription_type: newsletter,
        source: "test",
        legal_basis: "consent"
      )

      post public_email_unsubscribe_path(token: token), params: {type: "newsletter"}

      expect(response).to have_http_status(:ok)
      subscription = EmailSubscription.find_by!(person: person, subscription_type: newsletter)
      expect(subscription).not_to be_subscribed
      expect(EmailSuppression.suppressed?(workspace, person.email)).to be(false)
    end

    it "unsubscribes from all lists with global suppression when all=1" do
      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      Marketing::ConsentService.subscribe!(
        person: person,
        subscription_type: newsletter,
        source: "test",
        legal_basis: "consent"
      )

      post public_email_unsubscribe_path(token: token), params: {all: "1"}

      expect(response).to have_http_status(:ok)
      expect(EmailSuppression.suppressed?(workspace, person.email)).to be(true)
    end
  end
end
