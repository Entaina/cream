require "rails_helper"

RSpec.describe "Client portal consent", type: :request do
  include ActiveJob::TestHelper

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:person) { create_person!(workspace, email: "portal@example.com") }
  let!(:offer) do
    o = deal.offers.create!(workspace: workspace, user: users(:one), name: "Propuesta")
    o.versions.create!(user: users(:one), html_body: "<p>Oferta</p>")
    o
  end
  let!(:newsletter) do
    workspace.subscription_types.create!(name: "Newsletter portal", slug: "portal_news",
      default_consent_label: "Quiero la newsletter", client_portal_consent: "optional")
  end
  let!(:not_offered) { workspace.subscription_types.create!(name: "Eventos portal", slug: "portal_events") }

  before do
    deal.deal_contacts.create!(person: person)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
  end

  def login_token
    _grant, raw = ClientPortalLoginGrant.issue!(workspace: workspace, email: person.email)
    raw
  end

  def confirm_page
    get client_portal_access_consume_path(workspace_slug: workspace.slug, token: @token = login_token)
    response.body
  end

  it "offers only the subscriptions configured for the portal" do
    body = confirm_page
    expect(body).to include("Quiero la newsletter")
    expect(body).not_to include("Eventos portal")
  end

  it "does not offer subscriptions the person already answered" do
    Marketing::ConsentService.subscribe!(person: person, subscription_type: newsletter, source: "test")
    Marketing::ConsentService.unsubscribe!(person: person, subscription_type: newsletter, push_to_beehiiv: false)

    expect(confirm_page).not_to include("Quiero la newsletter")
  end

  it "does not offer anything to a suppressed address" do
    EmailSuppression.suppress!(workspace: workspace, address: person.email, reason: "unsubscribe")
    expect(confirm_page).not_to include("Quiero la newsletter")
  end

  it "lets the person in without ticking anything" do
    token = login_token
    expect {
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token)
    }.not_to change(EmailSubscription, :count)
    expect(response).to redirect_to(client_portal_offers_path(workspace_slug: workspace.slug))
  end

  it "records ticked consents with evidence, ignoring types that weren't offered" do
    token = login_token
    post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token),
      params: {consent_type_ids: [newsletter.id, not_offered.id]},
      headers: {"User-Agent" => "RSpec"}

    subscription = EmailSubscription.find_by!(person: person, subscription_type: newsletter)
    expect(subscription).to be_subscribed
    expect(subscription.source).to eq("client_portal:login")
    expect(subscription.legal_basis).to eq("consent")
    expect(subscription.metadata).to include(
      "marketing_consent_text" => "Quiero la newsletter",
      "consent_source" => "client_portal:login",
      "consent_ip" => "127.0.0.1",
      "user_agent" => "RSpec"
    )
    expect(EmailSubscription.exists?(person: person, subscription_type: not_offered)).to be(false)
  end

  it "links the privacy policy version the person was shown" do
    workspace.lead_form_templates.find_or_initialize_by(path: PrivacyPolicyVersion::POLICY_PATH)
      .update!(body: "<p>Política del workspace</p>")

    post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token),
      params: {consent_type_ids: [newsletter.id]}

    metadata = EmailSubscription.find_by!(person: person, subscription_type: newsletter).metadata
    version = PrivacyPolicyVersion.find(metadata["privacy_policy_version_id"])
    expect(version.policy_content).to include("Política del workspace")
    expect(metadata["privacy_policy_url"]).to include("/portal/#{workspace.slug}/privacidad")
  end

  it "records consents given when opening a shared proposal" do
    link = OfferShareLink.create!(workspace: workspace, offer: offer, person: person)
    _grant, raw = OfferAccessGrant.issue!(share_link: link, email: "guest@example.com")

    get public_offer_share_access_path(token: link.token, grant_token: raw)
    expect(response.body).to include("Quiero la newsletter")

    post public_offer_share_access_path(token: link.token, grant_token: raw), params: {consent_type_ids: [newsletter.id]}

    guest = Person.find_by_email(workspace, "guest@example.com")
    expect(EmailSubscription.find_by!(person: guest, subscription_type: newsletter).source).to eq("client_portal:offer_share")
  end

  it "records consents given when accepting a deal invitation" do
    invite = DealPortalInviteLink.create!(workspace: workspace, deal: deal)
    _grant, raw = DealPortalAccessGrant.issue!(invite_link: invite, email: "invited@example.com")

    post client_portal_deal_portal_invite_access_path(workspace_slug: workspace.slug, token: invite.token, grant_token: raw),
      params: {consent_type_ids: [newsletter.id]}

    invited = Person.find_by_email(workspace, "invited@example.com")
    expect(EmailSubscription.find_by!(person: invited, subscription_type: newsletter).source).to eq("client_portal:portal_invite")
  end

  describe "language" do
    let(:english) { {"Accept-Language" => "en-GB,en;q=0.9"} }

    it "shows and records the English texts to English browsers" do
      newsletter.update!(default_consent_label_en: "I want the newsletter", description_en: "Monthly news")
      token = login_token

      get client_portal_access_consume_path(workspace_slug: workspace.slug, token: token), headers: english
      expect(response.body).to include("I want the newsletter")
      expect(response.body).to include("Monthly news")
      expect(response.body).not_to include("Quiero la newsletter")

      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token),
        params: {consent_type_ids: [newsletter.id]}, headers: english

      metadata = EmailSubscription.find_by!(person: person, subscription_type: newsletter).metadata
      expect(metadata).to include("marketing_consent_text" => "I want the newsletter", "consent_locale" => "en")
    end

    it "falls back to the Spanish text when there is no English one" do
      get client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token), headers: english
      expect(response.body).to include("Quiero la newsletter")
    end

    it "shows the Spanish text to Spanish browsers" do
      newsletter.update!(default_consent_label_en: "I want the newsletter")

      get client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token),
        headers: {"Accept-Language" => "es-ES,es;q=0.9"}
      expect(response.body).to include("Quiero la newsletter")
      expect(response.body).not_to include("I want the newsletter")
    end
  end

  describe "required subscriptions" do
    let!(:updates) do
      workspace.subscription_types.create!(name: "Avisos portal", slug: "portal_updates",
        default_consent_label: "Acepto avisos de la propuesta", client_portal_consent: "required")
    end

    it "marks them as required on the confirmation page" do
      body = confirm_page
      expect(body).to match(/name="consent_type_ids\[\]"[^>]*value="#{updates.id}"[^>]*required|required[^>]*value="#{updates.id}"/)
    end

    it "keeps the link unspent and the person out until they are accepted" do
      token = login_token

      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token),
        params: {consent_type_ids: [newsletter.id]}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("client_portal.consent.required_missing"))
      expect(ClientPortalLoginGrant.last.used_at).to be_nil
      expect(EmailSubscription.exists?(person: person)).to be(false)

      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token),
        params: {consent_type_ids: [updates.id]}
      expect(response).to redirect_to(client_portal_offers_path(workspace_slug: workspace.slug))
      expect(EmailSubscription.find_by!(person: person, subscription_type: updates).metadata["client_portal_required"]).to be(true)
    end

    it "asks again someone who unsubscribed from a required type" do
      Marketing::ConsentService.subscribe!(person: person, subscription_type: updates, source: "test")
      Marketing::ConsentService.unsubscribe!(person: person, subscription_type: updates, push_to_beehiiv: false)

      expect(confirm_page).to include("Acepto avisos de la propuesta")
    end

    it "is not asked to someone already subscribed" do
      Marketing::ConsentService.subscribe!(person: person, subscription_type: updates, source: "test")

      expect(confirm_page).not_to include("Acepto avisos de la propuesta")
    end

    it "blocks a shared proposal until accepted" do
      link = OfferShareLink.create!(workspace: workspace, offer: offer, person: person)
      _grant, raw = OfferAccessGrant.issue!(share_link: link, email: "guest@example.com")

      expect {
        post public_offer_share_access_path(token: link.token, grant_token: raw)
      }.not_to change(OfferView, :count)
      expect(response).to have_http_status(:unprocessable_entity)

      post public_offer_share_access_path(token: link.token, grant_token: raw), params: {consent_type_ids: [updates.id]}
      expect(response).to have_http_status(:ok)
    end

    it "blocks a deal invitation until accepted" do
      invite = DealPortalInviteLink.create!(workspace: workspace, deal: deal)
      _grant, raw = DealPortalAccessGrant.issue!(invite_link: invite, email: "invited@example.com")

      expect {
        post client_portal_deal_portal_invite_access_path(workspace_slug: workspace.slug, token: invite.token, grant_token: raw)
      }.not_to change(DealContact, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "privacy page" do
    it "shows the workspace privacy policy" do
      workspace.lead_form_templates.find_or_initialize_by(path: PrivacyPolicyVersion::POLICY_PATH)
        .update!(body: "<p>Política del workspace</p>")

      get client_portal_privacy_path(workspace_slug: workspace.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Política del workspace")
    end

    it "returns not found when the workspace has no policy" do
      workspace.lead_form_templates.where(path: PrivacyPolicyVersion::POLICY_PATH).delete_all

      get client_portal_privacy_path(workspace_slug: workspace.slug)
      expect(response).to have_http_status(:not_found)
    end
  end
end
