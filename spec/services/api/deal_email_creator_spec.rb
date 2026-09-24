require "rails_helper"

RSpec.describe Api::DealEmailCreator do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:deal) do
    person = create_person!(workspace, email: "contact@example.com")
    create_deal!(workspace, contacts: [person], company: person.company)
  end

  it "builds a message for the deal with resolved recipient" do
    creator = described_class.new(
      workspace: workspace,
      user: user,
      deal: deal,
      email_attrs: {subject: "Hi", body: "Body"}
    )
    message = creator.build

    expect(message).to be_valid
    expect(message.record).to eq(deal)
    expect(message.to_address).to eq(deal.contacts.first.email)
    expect(message.subject).to eq("Hi")
  end

  it "rejects too many attachments" do
    files = Array.new(EmailMessage::MAX_ATTACHMENTS + 1) do |i|
      ActionDispatch::Http::UploadedFile.new(
        tempfile: StringIO.new("x"),
        filename: "f#{i}.txt",
        type: "text/plain"
      )
    end

    expect {
      described_class.new(
        workspace: workspace,
        user: user,
        deal: deal,
        email_attrs: {subject: "S", body: "B", to_address: "a@b.com"},
        attachments: files
      ).build
    }.to raise_error(Api::DealEmailCreator::InvalidAttachment, /cannot exceed/)
  end

  describe ".json" do
    it "serializes the message" do
      message = workspace.email_messages.create!(
        user: user,
        record: deal,
        to_address: "x@y.com",
        subject: "S",
        body: "B",
        status: "pending",
        direction: "outbound"
      )

      expect(described_class.json(message)).to include(
        id: message.id,
        to_address: "x@y.com",
        subject: "S",
        status: "pending"
      )
    end
  end
end
