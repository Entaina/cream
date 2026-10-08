require "rails_helper"

RSpec.describe "Public offer shares", type: :request do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:sharer) { create_person!(workspace, email: "sharer@example.com") }
  let!(:offer) do
    o = deal.offers.create!(workspace: workspace, user: users(:one), name: "Propuesta")
    o.versions.create!(user: users(:one), html_body: "<p>Compartida</p>")
    o
  end
  let!(:share_link) do
    deal.deal_contacts.create!(person: sharer)
    OfferShareLink.create!(workspace: workspace, offer: offer, person: sharer)
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(true)
  end

  def grant_token(email = "guest@example.com")
    _grant, raw = OfferAccessGrant.issue!(share_link: share_link, email: email)
    raw
  end

  describe "GET /s/:token" do
    it "shows the email form" do
      get public_offer_share_path(token: share_link.token)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Propuesta")
    end

    it "returns not found when revoked" do
      share_link.revoke!
      get public_offer_share_path(token: share_link.token)
      expect(response).to have_http_status(:not_found)
    end

    it "returns not found once the sharer is no longer a contact of the deal" do
      deal.deal_contacts.find_by!(person: sharer).destroy!
      get public_offer_share_path(token: share_link.token)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /s/:token" do
    it "creates a grant and enqueues mail without creating a person" do
      expect {
        post public_offer_share_path(token: share_link.token), params: { email: "guest@example.com" }
      }.to change(OfferAccessGrant, :count).by(1)
        .and have_enqueued_mail(ClientPortalMailer, :offer_access_link)
        .and change(Person, :count).by(0)

      expect(response).to redirect_to(public_offer_share_path(token: share_link.token))
    end

    it "stores only the token digest" do
      post public_offer_share_path(token: share_link.token), params: { email: "guest@example.com" }
      grant = OfferAccessGrant.last
      expect(grant.token_digest).to match(/\A\h{64}\z/)
    end

    it "caps the emails a single link can trigger" do
      OneTimeGrant::MAX_ISSUED_PER_HOUR.times { |i| OfferAccessGrant.issue!(share_link: share_link, email: "g#{i}@example.com") }

      expect {
        post public_offer_share_path(token: share_link.token), params: { email: "another@example.com" }
      }.not_to have_enqueued_mail(ClientPortalMailer, :offer_access_link)
    end
  end

  describe "the one-time link" do
    def open_link(raw, link: share_link)
      post public_offer_share_access_path(token: link.token, grant_token: raw)
    end

    it "does not spend the grant or create anything on GET" do
      raw = grant_token

      expect {
        get public_offer_share_access_path(token: share_link.token, grant_token: raw)
      }.to change(Person, :count).by(0).and change(OfferView, :count).by(0)

      expect(response).to have_http_status(:ok)
      expect(OfferAccessGrant.last.used_at).to be_nil
    end

    it "on POST creates person and marked deal contact, records the view and renders the offer" do
      expect { open_link(grant_token) }.to change(Person, :count).by(1)
        .and change(DealContact, :count).by(1)
        .and change(OfferView, :count).by(1)

      contact = deal.deal_contacts.find_by!(person: Person.find_by_email(workspace, "guest@example.com"))
      expect(contact.source).to eq("offer_share")
      expect(contact.offer_share_link).to eq(share_link)
      expect(OfferView.last.offer_share_link).to eq(share_link)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Compartida")
    end

    it "is single use, so a forwarded email can't be reused" do
      raw = grant_token
      open_link(raw)
      open_link(raw)
      expect(response).to have_http_status(:gone)
    end

    it "is valid for an hour" do
      raw = grant_token
      travel 59.minutes do
        open_link(raw)
        expect(response).to have_http_status(:ok)
      end
    end

    it "expires after an hour" do
      raw = grant_token
      travel 61.minutes do
        open_link(raw)
      end
      expect(response).to have_http_status(:gone)
    end

    it "can't be used with another share link's token" do
      other_sharer = create_person!(workspace, email: "other@example.com")
      deal.deal_contacts.create!(person: other_sharer)
      other_link = OfferShareLink.create!(workspace: workspace, offer: offer, person: other_sharer)

      open_link(grant_token, link: other_link)
      expect(response).to have_http_status(:gone)
    end

    it "stops working once revoked, and the email can't request another" do
      raw = grant_token
      OfferAccessGrant.last.revoke_for_offer!

      open_link(raw)
      expect(response).to have_http_status(:gone)
      expect {
        post public_offer_share_path(token: share_link.token), params: { email: "guest@example.com" }
      }.not_to have_enqueued_mail(ClientPortalMailer, :offer_access_link)
    end

    it "caps the emails sent to one address" do
      OfferAccessGrant::MAX_PER_EMAIL_PER_HOUR.times { grant_token }

      expect {
        post public_offer_share_path(token: share_link.token), params: { email: "guest@example.com" }
      }.not_to have_enqueued_mail(ClientPortalMailer, :offer_access_link)
    end

    it "reuses an existing person without changing an existing deal contact mark" do
      existing = create_person!(workspace, email: "guest@example.com")
      deal.deal_contacts.create!(person: existing)

      expect { open_link(grant_token) }.not_to change(DealContact, :count)

      expect(deal.deal_contacts.find_by(person: existing).source).to be_nil
    end
  end
end
