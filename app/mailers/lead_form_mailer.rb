class LeadFormMailer < ApplicationMailer
  def responsible_notification(responsible:, lead_form:, submission:, deal:)
    @responsible = responsible
    @lead_form = lead_form
    @submission = submission
    @deal = deal
    @person = submission.person
    @company = @person&.company
    @data = submission.data
    @metadata = submission.metadata

    with_mailer_locale(responsible.locale) do
      mail(to: responsible.email_address, subject: notification_subject)
    end
  end

  private

  def notification_subject
    descriptor = lead_descriptor
    lead_suffix = descriptor.present? ? t("lead_form_mailer.responsible_notification.subject_lead_suffix", descriptor: descriptor) : ""

    t("lead_form_mailer.responsible_notification.subject", form_name: @lead_form.name, lead_suffix: lead_suffix)
  end

  def lead_descriptor
    lead_name = @person&.display_name.presence
    company_name = @company&.name.presence
    return company_name if lead_name.blank?

    company_name.present? ? "#{lead_name} (#{company_name})" : lead_name
  end

  def mailjet_workspace = @lead_form.workspace
end
