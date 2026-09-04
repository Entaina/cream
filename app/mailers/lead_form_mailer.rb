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

    mail(to: responsible.email_address, subject: notification_subject)
  end

  private

  def notification_subject
    lead_name = @person&.display_name.presence
    company_name = @company&.name.presence
    descriptor = lead_name.to_s
    descriptor += " (#{company_name})" if lead_name && company_name

    [ "Nuevo lead", @lead_form.name, descriptor.presence ].compact.join(" · ")
  end

  def mailjet_workspace = @lead_form.workspace
end
