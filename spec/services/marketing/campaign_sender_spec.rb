require "rails_helper"

RSpec.describe Marketing::CampaignSender do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "campaign@example.com") }
  let(:template) { create_email_template!(workspace, user: user) }
  let(:segment) do
    workspace.segments.create!(
      user: user,
      name: "Everyone",
      record_type: "Person",
      filters: {}
    )
  end
  let(:campaign) do
    workspace.campaigns.create!(name: "Newsletter", status: "draft")
  end
  let(:campaign_send) do
    workspace.campaign_sends.create!(
      campaign: campaign,
      segment: segment,
      email_template: template,
      user: user,
      status: "pending"
    )
  end
  let(:newsletter_type) do
    SubscriptionType.ensure_defaults!(workspace)
    workspace.subscription_types.find_by!(slug: "newsletter")
  end
  let(:esp_double) { instance_double(Marketing::Esp::SmtpAdapter, deliver!: true) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:lead_scoring).and_return(false)
    Marketing::ConsentService.subscribe!(
      person: person,
      subscription_type: newsletter_type,
      source: "test",
      legal_basis: "consent"
    )
    allow(Marketing::Esp::Client).to receive(:for).and_return(esp_double)
  end

  it "sends to consented segment members and marks the send complete" do
    described_class.call(campaign_send: campaign_send)

    expect(esp_double).to have_received(:deliver!).once
    expect(campaign_send.reload.status).to eq("sent")
    expect(campaign.reload.status).to eq("sent")
    expect(workspace.email_messages.where(marketing_send: true).count).to eq(1)
  end

  it "excludes suppressed recipients before sending" do
    EmailSuppression.suppress!(workspace: workspace, address: person.email, reason: "manual")

    described_class.call(campaign_send: campaign_send)

    expect(esp_double).not_to have_received(:deliver!)
    expect(campaign_send.reload.stats["sent"]).to eq(0)
    expect(workspace.email_messages.where(marketing_send: true).count).to eq(0)
  end
end
