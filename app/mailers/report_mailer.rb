class ReportMailer < ApplicationMailer
  def scheduled_report(report)
    @report = report
    @config = report.config_params
    @result = ReportRunner.new(workspace: report.workspace, **@config).run

    with_mailer_locale(report.user.locale) do
      mail(
        to: report.user.email_address,
        subject: t("report_mailer.scheduled_report.subject", name: report.name)
      )
    end
  end

  private

  def mailjet_workspace = @report.workspace
end
