class CampaignPolicy < MarketingAdminPolicy
  def send_campaign? = update?
end
