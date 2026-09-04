require "rails_helper"

RSpec.describe Marketing::LinkRewriter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "link@example.com") }
  let(:campaign) do
    workspace.campaigns.create!(
      name: "Launch",
      status: "draft",
      utm_source: "newsletter",
      utm_medium: "email",
      utm_campaign: "launch"
    )
  end
  let(:message) do
    workspace.email_messages.create!(
      user: user,
      record: person,
      to_address: person.email,
      subject: "Links",
      body: '<a href="https://example.com/page">Click</a>',
      campaign: campaign,
      marketing_send: true
    )
  end

  it "rewrites external links to tracking URLs with UTM params" do
    rewritten = described_class.rewrite(html: message.body, message: message, campaign: campaign)

    expect(rewritten).to include("email_tracking/click/")
    expect(rewritten).to include("utm_source")
  end

  it "skips mailto and anchor links" do
    html = '<a href="mailto:a@b.com">Mail</a><a href="#section">Anchor</a>'
    rewritten = described_class.rewrite(html: html, message: message, campaign: campaign)

    expect(rewritten).to include('href="mailto:a@b.com"')
    expect(rewritten).to include('href="#section"')
  end
end
