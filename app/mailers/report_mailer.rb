class ReportMailer < ApplicationMailer
  def scheduled_report(report)
    @report = report
    @config = report.config_params
    @result = ReportRunner.new(workspace: report.workspace, **@config).run

    mail(to: report.user.email_address, subject: "Your “#{report.name}” report")
  end

  private

  def mailjet_workspace = @report.workspace
end
