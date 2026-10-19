require "rails_helper"

RSpec.describe "Offer share link revocation", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:person) { create_person!(workspace, email: "sharer@example.com") }
  let!(:offer) do
    o = deal.offers.create!(workspace: workspace, user: member, name: "Propuesta")
    o.versions.create!(user: member, html_body: "<p>x</p>", published_at: Time.current)
    o
  end
  let!(:share_link) { OfferShareLink.create!(workspace: workspace, offer: offer, person: person) }

  before { sign_in_as(member) }

  it "revokes the link for editors" do
    delete deal_offer_share_link_path(deal, offer, share_link)

    expect(response).to redirect_to(deal_path(deal, tab: "offers"))
    expect(share_link.reload.revoked_at).to be_present
  end
end
