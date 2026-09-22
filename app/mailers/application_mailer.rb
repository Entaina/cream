class ApplicationMailer < ActionMailer::Base
  include ActionView::Helpers::DateHelper

  layout "mailer"
  helper EmailHelper
  after_action :assign_mailjet_workspace

  private

  def with_mailer_locale(locale = nil, &block)
    loc = locale.to_s.presence_in(User::LOCALES) || I18n.default_locale
    I18n.with_locale(loc, &block)
  end

  def assign_mailjet_workspace
    workspace = mailjet_workspace
    headers[MailjetDeliveryInterceptor::HEADER] = workspace.id.to_s if workspace
  end

  def mailjet_workspace
    nil
  end
end
