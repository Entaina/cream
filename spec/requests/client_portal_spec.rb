require "rails_helper"

RSpec.describe "Client portal", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

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

  before do
    deal.deal_contacts.create!(person: person)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(true)
  end

  def login_token_for(email)
    _grant, raw = ClientPortalLoginGrant.issue!(workspace: workspace, email: email)
    raw
  end

  def sign_in_via_portal!
    post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token_for(person.email))
  end

  describe "requesting a login link" do
    it "enqueues the login mail for known contacts and always shows the same message" do
      expect {
        post client_portal_access_request_path(workspace_slug: workspace.slug), params: { email: person.email }
      }.to have_enqueued_mail(ClientPortalMailer, :login_link)

      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
      follow_redirect!
      expect(response.body).to include(I18n.t("client_portal.sessions.link_sent"))
    end

    it "does not enqueue mail for unknown emails but responds the same" do
      expect {
        post client_portal_access_request_path(workspace_slug: workspace.slug), params: { email: "unknown@example.com" }
      }.not_to have_enqueued_mail(ClientPortalMailer, :login_link)

      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end

    it "caps login emails per address" do
      ClientPortalLoginGrant::MAX_PER_EMAIL_PER_HOUR.times { ClientPortalLoginGrant.issue!(workspace: workspace, email: person.email) }

      expect {
        post client_portal_access_request_path(workspace_slug: workspace.slug), params: { email: person.email }
      }.not_to have_enqueued_mail(ClientPortalMailer, :login_link)
    end
  end

  describe "using a login link" do
    it "does not spend the token on GET, so mail scanners can't burn it" do
      token = login_token_for(person.email)

      get client_portal_access_consume_path(workspace_slug: workspace.slug, token: token)
      expect(response).to have_http_status(:ok)
      expect(ClientPortalLoginGrant.last.used_at).to be_nil
    end

    it "signs in on POST and lists the contact's offers" do
      sign_in_via_portal!

      expect(response).to redirect_to(client_portal_offers_path(workspace_slug: workspace.slug))
      get client_portal_offers_path(workspace_slug: workspace.slug)
      expect(response.body).to include("Propuesta")
    end

    it "is single use" do
      token = login_token_for(person.email)
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token)

      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
      expect(flash[:alert]).to eq(I18n.t("client_portal.sessions.invalid_link"))
    end

    it "rejects expired tokens" do
      token = login_token_for(person.email)
      travel 31.minutes do
        post client_portal_access_consume_path(workspace_slug: workspace.slug, token: token)
      end
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end

    it "rejects tokens issued for another workspace" do
      token = login_token_for(person.email)
      other = workspaces(:two)

      post client_portal_access_consume_path(workspace_slug: other.slug, token: token)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: other.slug))
    end
  end

  describe "session scope" do
    it "does not accept a session from another workspace's portal" do
      sign_in_via_portal!

      get client_portal_offers_path(workspace_slug: workspaces(:two).slug)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspaces(:two).slug))
    end

    it "ends the session once the contact is removed from all their deals" do
      sign_in_via_portal!
      deal.deal_contacts.find_by!(person: person).destroy!

      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end

    it "loses access to a deal's offers once the contact is removed from it" do
      create_deal!(workspace, pipeline: pipeline).deal_contacts.create!(person: person)
      sign_in_via_portal!
      deal.deal_contacts.find_by!(person: person).destroy!

      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to have_http_status(:not_found)
    end

    it "signs out" do
      sign_in_via_portal!
      delete client_portal_session_path(workspace_slug: workspace.slug)

      get client_portal_offers_path(workspace_slug: workspace.slug)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end
  end

  describe "viewing an offer" do
    it "records a view and renders the current version" do
      sign_in_via_portal!

      expect {
        get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      }.to change(OfferView, :count).by(1)
        .and change { deal.activities.where(action: "offer_viewed").count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Oferta")
    end

    it "sends no-store, same-origin and noindex headers" do
      sign_in_via_portal!
      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)

      expect(response.headers["Cache-Control"]).to include("no-store")
      expect(response.headers["Referrer-Policy"]).to eq("same-origin")
      expect(response.headers["X-Robots-Tag"]).to include("noindex")
    end

    it "returns not found for offers outside the contact scope, without recording a view" do
      other_deal = create_deal!(workspace, pipeline: pipeline)
      other_offer = other_deal.offers.create!(workspace: workspace, user: users(:one), name: "Otra")
      other_offer.versions.create!(user: users(:one), html_body: "<p>x</p>")

      sign_in_via_portal!
      expect {
        get client_portal_offer_path(workspace_slug: workspace.slug, id: other_offer.id)
      }.not_to change(OfferView, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "requires a session" do
      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end
  end

  describe "contacts added through a shared proposal" do
    let(:guest) { create_person!(workspace, email: "guest@example.com") }

    before do
      link = OfferShareLink.create!(workspace: workspace, offer: offer, person: person)
      deal.deal_contacts.create!(person: guest, source: "offer_share", offer_share_link: link)
    end

    it "are not sent a login link" do
      expect {
        post client_portal_access_request_path(workspace_slug: workspace.slug), params: { email: guest.email }
      }.not_to have_enqueued_mail(ClientPortalMailer, :login_link)
    end

    it "can't sign in even with a login link" do
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token_for(guest.email))
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
      expect(flash[:alert]).to eq(I18n.t("client_portal.sessions.no_access"))

      get client_portal_offers_path(workspace_slug: workspace.slug)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
    end

    it "lose a session they already had" do
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token_for(guest.email))
      deal.deal_contacts.find_by!(person: guest).update!(source: "portal_invite")
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token_for(guest.email))
      deal.deal_contacts.find_by!(person: guest).update!(source: "offer_share")

      get client_portal_offers_path(workspace_slug: workspace.slug)
      expect(response).to redirect_to(client_portal_root_path(workspace_slug: workspace.slug))
      expect(flash[:alert]).to eq(I18n.t("client_portal.sessions.no_access"))
    end

    it "still can't reach the deal's offers when they are a regular contact elsewhere" do
      other_deal = create_deal!(workspace, pipeline: pipeline)
      other_deal.deal_contacts.create!(person: guest)
      post client_portal_access_consume_path(workspace_slug: workspace.slug, token: login_token_for(guest.email))

      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to have_http_status(:not_found)
      post share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "sharing" do
    it "does not create a link on GET" do
      sign_in_via_portal!

      expect {
        get share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      }.not_to change(OfferShareLink, :count)
    end

    it "creates one link per contact and offer on POST and reuses it" do
      sign_in_via_portal!

      post share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response).to redirect_to(share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id))
      post share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)

      expect(OfferShareLink.where(offer: offer, person: person).count).to eq(1)
    end

    it "lets any contact with portal access see and revoke guest access links" do
      other_sharer = create_person!(workspace, email: "colleague@example.com")
      deal.deal_contacts.create!(person: other_sharer)
      link = OfferShareLink.create!(workspace: workspace, offer: offer, person: other_sharer)
      grant, _raw = OfferAccessGrant.issue!(share_link: link, email: "guest@example.com")
      sign_in_via_portal!

      get share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response.body).to include("guest@example.com")

      delete revoke_access_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id, grant_id: grant.id)
      expect(response).to redirect_to(share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id))
      expect(grant.reload.revoked_at).to be_present
    end

    it "does not revoke access links of another offer" do
      other_offer = deal.offers.create!(workspace: workspace, user: users(:one), name: "Otra")
      link = OfferShareLink.create!(workspace: workspace, offer: other_offer, person: person)
      grant, _raw = OfferAccessGrant.issue!(share_link: link, email: "guest@example.com")
      sign_in_via_portal!

      delete revoke_access_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id, grant_id: grant.id)
      expect(response).to have_http_status(:not_found)
      expect(grant.reload.revoked_at).to be_nil
    end

    it "keeps a revoked link revoked" do
      link = OfferShareLink.create!(workspace: workspace, offer: offer, person: person)
      link.revoke!
      sign_in_via_portal!

      post share_client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(link.reload.revoked_at).to be_present
    end
  end

  describe "workspace public layout" do
    before do
      layout = workspace.lead_form_templates.create!(
        kind: "layout",
        path: "public/layouts/portal_wrap",
        partial: false,
        body: '<div data-test="public-layout-header">Header</div>{{ content }}'
      )
      workspace.update!(client_portal_layout_template: layout)
    end

    it "is independent from the booking layout" do
      workspace.update!(client_portal_layout_template: nil, public_layout_template: workspace.client_portal_layout_template)

      get client_portal_root_path(workspace_slug: workspace.slug)
      expect(response.body).not_to include('data-test="public-layout-header"')
    end

    it "wraps portal pages" do
      get client_portal_root_path(workspace_slug: workspace.slug)
      expect(response.body).to include('data-test="public-layout-header"')

      sign_in_via_portal!
      get client_portal_offers_path(workspace_slug: workspace.slug)
      expect(response.body).to include('data-test="public-layout-header"')
      expect(response.body).to include("Propuesta")
    end

    it "wraps the shared proposal pages" do
      link = OfferShareLink.create!(workspace: workspace, offer: offer, person: person)
      get public_offer_share_path(token: link.token)
      expect(response.body).to include('data-test="public-layout-header"')
    end

    it "does not wrap the proposal document itself" do
      sign_in_via_portal!
      get client_portal_offer_path(workspace_slug: workspace.slug, id: offer.id)
      expect(response.body).not_to include('data-test="public-layout-header"')
    end
  end

  describe "feature flag" do
    it "returns not found when disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(false)
      get client_portal_root_path(workspace_slug: workspace.slug)
      expect(response).to have_http_status(:not_found)
    end
  end
end
