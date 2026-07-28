class LeadFormMailer < ApplicationMailer
  def responsible_notification(responsible:, lead_form:, submission:, deal:)
    @responsible = responsible
    @lead_form = lead_form
    @submission = submission
    @deal = deal
    @data = submission.data
    @metadata = submission.metadata

    mail(to: responsible.email_address, subject: "Nuevo lead: #{lead_form.name}")
  end
end
