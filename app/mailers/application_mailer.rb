class ApplicationMailer < ActionMailer::Base
  layout "mailer"
  helper EmailHelper
  after_action :assign_mailjet_workspace

  private

  def assign_mailjet_workspace
    workspace = mailjet_workspace
    headers[MailjetDeliveryInterceptor::HEADER] = workspace.id.to_s if workspace
  end

  def mailjet_workspace
    nil
  end
end
