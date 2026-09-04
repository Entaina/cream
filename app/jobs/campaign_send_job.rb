class CampaignSendJob < ApplicationJob
  queue_as :default

  def perform(campaign_send_id)
    campaign_send = CampaignSend.find(campaign_send_id)
    return if campaign_send.status == "cancelled"

    Marketing::CampaignSender.call(campaign_send: campaign_send)
  end
end
