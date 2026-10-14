require "rails_helper"

RSpec.describe ClientPortalMailer, type: :mailer do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  before do
    ActionMailer::Base.default from: "Cream <noreply@example.com>"
  end

  describe "#login_link" do
    it "sends to the contact with the consume URL" do
      mail = described_class.login_link(workspace: workspace, email: "a@example.com", token: "tok123")

      expect(mail.to).to eq(["a@example.com"])
      expect(mail.body.encoded).to include("tok123")
    end

    it "uses the workspace portal sender name when configured" do
      workspace.update!(mail_from_name: "Entaina")

      mail = described_class.login_link(workspace: workspace, email: "a@example.com", token: "tok123")

      expect(mail.header["From"].value).to eq("Entaina <noreply@example.com>")
    end

    it "keeps the default from when mail_from_name is blank" do
      mail = described_class.login_link(workspace: workspace, email: "a@example.com", token: "tok123")

      expect(mail.header["From"].value).to eq("Cream <noreply@example.com>")
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
