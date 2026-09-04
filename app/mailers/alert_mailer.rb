class AlertMailer < ApplicationMailer
  def alert_email(user:, rule:, deal:)
    @user = user
    @rule = rule
    @deal = deal
    @deal_url = deal_url(deal)

    mail(to: user.email_address, subject: "[Cream] #{rule.name}")
  end

  private

  def mailjet_workspace = @deal.workspace
end
