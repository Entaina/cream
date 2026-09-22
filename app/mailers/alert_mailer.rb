class AlertMailer < ApplicationMailer
  def alert_email(user:, rule:, deal:)
    @user = user
    @rule = rule
    @deal = deal
    @deal_url = deal_url(deal)

    with_mailer_locale(user.locale) do
      mail(to: user.email_address, subject: t("alert_mailer.alert_email.subject", rule_name: rule.name))
    end
  end

  private

  def mailjet_workspace = @deal.workspace
end
