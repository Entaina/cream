class ScheduledReportsJob < ApplicationJob
  queue_as :default

  # Runs daily (see config/recurring.yml). Emails every scheduled report whose
  # interval has elapsed, then stamps last_sent_at so it isn't re-sent until the
  # next interval.
  def perform
    Report.scheduled.find_each do |report|
      next unless report.due_to_send?

      ReportMailer.scheduled_report(report).deliver_later
      report.update_column(:last_sent_at, Time.current)
    end
  end
end
