require "rails_helper"

RSpec.describe ClientPortalMailer, type: :mailer do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  describe "#login_link" do
    it "sends to the contact with the consume URL" do
      mail = described_class.login_link(workspace: workspace, email: "a@example.com", token: "tok123")

      expect(mail.to).to eq(["a@example.com"])
      expect(mail.body.encoded).to include("tok123")
    end
  end

  describe "#offer_access_link" do
    it "includes the personal access URL" do
      share_link = OfferShareLink.new(token: "sharetok", workspace: workspace, offer: Offer.new(name: "X"))
      grant = OfferAccessGrant.new(email: "b@example.com", offer_share_link: share_link)
      allow(share_link).to receive(:offer).and_return(Offer.new(name: "Propuesta"))

      mail = described_class.offer_access_link(grant: grant, raw_token: "grantraw")

      expect(mail.to).to eq(["b@example.com"])
      expect(mail.body.encoded).to include("grantraw")
      expect(mail.body.encoded).to include("sharetok")
    end
  end
end
