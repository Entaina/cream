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

    it "links multiple contacts when contact_emails are provided" do
      cc_thread = thread.merge(
        messages: thread[:messages] + [
          {
            from: "User One <one@example.com>",
            to: "Buyer <buyer@acme.com>",
            cc: "Partner <partner@acme.com>",
            subject: "Pricing",
            body: "Loop",
            gmail_message_id: "gm-2",
            rfc822_message_id: "<msg-2@acme.com>",
            sent_at: 30.minutes.ago.iso8601
          }
        ]
      )

      result = linker.link(
        thread: cc_thread,
        new_deal: {
          name: "From email",
          create_company: true,
          contact_emails: %w[partner@acme.com]
        }
      )

      deal = Deal.find(result.dig(:deal, :id))
      expect(deal.contacts.map(&:email)).to contain_exactly("buyer@acme.com", "partner@acme.com")
    end
  end

  describe "#add_contacts!" do
    let(:deal) { create_deal!(workspace, company: company) }

    it "appends a new person on the deal company" do
      payload = linker.add_contacts!(
        deal: deal,
        contacts: [{email: "partner@acme.com", name: "Partner Person"}]
      )

      deal.reload
      expect(deal.contacts.map(&:email)).to include("partner@acme.com")
      expect(deal.contacts.find_by(email: "partner@acme.com").first_name).to eq("Partner")
      expect(payload[:contact_emails]).to include("partner@acme.com")
    end

    it "reuses an existing person from the same company" do
      person = create_person!(workspace, company: company, email: "partner@acme.com")

      linker.add_contacts!(deal: deal, contacts: [{email: "partner@acme.com"}])

      expect(deal.reload.contacts).to include(person)
    end

    it "ignores the connected user's email" do
      expect {
        linker.add_contacts!(deal: deal, contacts: [{email: user.email_address}])
      }.not_to change { deal.reload.contacts.count }
    end

    it "raises when the person belongs to another company" do
      other_company = workspace.companies.create!(name: "Other Co")
      create_person!(workspace, company: other_company, email: "outsider@other.com")

      expect {
        linker.add_contacts!(deal: deal, contacts: [{email: "outsider@other.com"}])
      }.to raise_error(GmailThreadLinker::ContactOutsideCompany)
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
