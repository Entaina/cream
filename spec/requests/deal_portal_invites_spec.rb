require "rails_helper"

RSpec.describe "Deal portal invites", type: :request do
  include ActiveJob::TestHelper

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let!(:invite) { DealPortalInviteLink.create!(workspace: workspace, deal: deal) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:client_portal).and_return(true)
  end

  def grant_token(email = "newcontact@example.com")
    _grant, raw = DealPortalAccessGrant.issue!(invite_link: invite, email: email)
    raw
  end

  it "does not create the contact on GET" do
    expect {
      get client_portal_deal_portal_invite_access_path(workspace_slug: workspace.slug, token: invite.token, grant_token: grant_token)
    }.not_to change(DealContact, :count)
    expect(response).to have_http_status(:ok)
  end

  it "registers the contact on POST and redirects to the portal" do
    post client_portal_deal_portal_invite_access_path(workspace_slug: workspace.slug, token: invite.token, grant_token: grant_token)

    expect(response).to redirect_to(client_portal_offers_path(workspace_slug: workspace.slug))
    contact = deal.deal_contacts.find_by!(person: Person.find_by_email(workspace, "newcontact@example.com"))
    expect(contact.source).to eq("portal_invite")
  end

  it "grants portal access to a contact that came through a shared proposal" do
    guest = create_person!(workspace, email: "newcontact@example.com")
    deal.deal_contacts.create!(person: guest, source: "offer_share")

    post client_portal_deal_portal_invite_access_path(workspace_slug: workspace.slug, token: invite.token, grant_token: grant_token)

    expect(deal.deal_contacts.find_by!(person: guest).source).to eq("portal_invite")
  end

  it "returns not found when the invite is revoked" do
    invite.revoke!
    get client_portal_deal_portal_invite_path(workspace_slug: workspace.slug, token: invite.token)
    expect(response).to have_http_status(:not_found)
  end

  it "returns not found under another workspace's slug" do
    get client_portal_deal_portal_invite_path(workspace_slug: workspaces(:two).slug, token: invite.token)
    expect(response).to have_http_status(:not_found)
  end

  it "caps the emails a single invite can trigger" do
    OneTimeGrant::MAX_ISSUED_PER_HOUR.times { |i| DealPortalAccessGrant.issue!(invite_link: invite, email: "g#{i}@example.com") }

    expect {
      post client_portal_deal_portal_invite_path(workspace_slug: workspace.slug, token: invite.token), params: {email: "x@example.com"}
    }.not_to have_enqueued_mail(ClientPortalMailer, :deal_portal_invite_link)
  end
end
