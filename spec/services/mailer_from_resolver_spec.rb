require "rails_helper"

RSpec.describe MailerFromResolver do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  before do
    ActionMailer::Base.default from: "Cream <noreply@example.com>"
  end

  describe ".portal_from" do
    it "returns formatted from when mail_from_name is set" do
      workspace.update!(mail_from_name: "Entaina")

      expect(described_class.portal_from(workspace)).to eq("Entaina <noreply@example.com>")
    end

    it "returns nil when mail_from_name is blank" do
      workspace.update!(mail_from_name: nil)

      expect(described_class.portal_from(workspace)).to be_nil
    end
  end
end
