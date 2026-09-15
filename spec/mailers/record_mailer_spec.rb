require "rails_helper"

RSpec.describe RecordMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }

  def build_message(body:)
    EmailMessage.create!(
      workspace: workspace,
      user: user,
      record: person,
      to_address: "recipient@example.com",
      subject: "Subject",
      body: body,
      status: "pending",
      direction: "outbound"
    )
  end

  describe "#tracked_email" do
    it "wraps fragment bodies with mailer layout" do
      message = build_message(body: "<p>Hello</p>")
      mail = described_class.tracked_email(message: message)

      expect(mail.body.encoded).to include("<p>Hello</p>")
      expect(mail.body.encoded).to include("<html>")
    end

    it "skips mailer layout for full html documents and inserts pixel before body end" do
      document = "<!DOCTYPE html><html><body><table><tr><td>Hi</td></tr></table></body></html>"
      message = build_message(body: document)
      mail = described_class.tracked_email(message: message)

      encoded = mail.body.encoded
      expect(encoded).to include("<table>")
      expect(encoded).to include("email_tracking/open")
      expect(encoded).to match(/<img[^>]+><\/body>/i)
    end
  end
end
