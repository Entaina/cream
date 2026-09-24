require "rails_helper"

RSpec.describe GmailThreadLinker do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:linker) { described_class.new(workspace: workspace, user: user) }
  let(:company) { companies(:acme) }

  let(:thread) do
    {
      gmail_thread_id: "thread-1",
      messages: [
        {
          from: "Buyer <buyer@acme.com>",
          to: "User One <one@example.com>",
          subject: "Pricing",
          body: "Hello",
          gmail_message_id: "gm-1",
          rfc822_message_id: "<msg-1@acme.com>",
          sent_at: 1.hour.ago.iso8601
        }
      ]
    }
  end

  describe "#link" do
    it "imports messages onto an existing deal" do
      deal = create_deal!(workspace, company: company)

      result = linker.link(thread: thread, deal_id: deal.id)

      expect(result[:imported_count]).to eq(1)
      expect(deal.email_messages.count).to eq(1)
      expect(deal.email_messages.first.gmail_thread_id).to eq("thread-1")
    end

    it "raises CompanyRequired when company must be created explicitly" do
      expect {
        linker.link(thread: thread, new_deal: {name: "From email"})
      }.to raise_error(GmailThreadLinker::CompanyRequired)
    end

    it "creates deal and company when create_company is confirmed" do
      expect {
        linker.link(thread: thread, new_deal: {name: "From email", create_company: true})
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
    end
  end

  describe "domain handling" do
    it "ignores free email domains for company suggestions" do
      status = linker.status(
        gmail_thread_id: nil,
        participant_emails: ["someone@gmail.com"]
      )

      expect(status[:suggested_companies]).to be_empty
    end
  end
end
