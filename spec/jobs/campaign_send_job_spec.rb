require "rails_helper"

RSpec.describe CampaignSendJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }

  it "delegates to CampaignSender" do
    campaign = workspace.campaigns.create!(name: "Blast", status: "draft")
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})
    send_record = workspace.campaign_sends.create!(
      campaign: campaign, segment: segment, user: admin, status: "pending", delivery_mode: "email"
    )

    sender = instance_double(Marketing::CampaignSender)
    allow(Marketing::CampaignSender).to receive(:call).and_return(sender)

    described_class.perform_now(send_record.id)

    expect(Marketing::CampaignSender).to have_received(:call).with(campaign_send: send_record)
  end

  it "does not send cancelled campaign sends" do
    campaign = workspace.campaigns.create!(name: "Blast", status: "draft")
    segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})
    send_record = workspace.campaign_sends.create!(
      campaign: campaign, segment: segment, user: admin, status: "cancelled", delivery_mode: "email"
    )

    allow(Marketing::CampaignSender).to receive(:call)

    described_class.perform_now(send_record.id)

    expect(Marketing::CampaignSender).not_to have_received(:call)
  end
end
