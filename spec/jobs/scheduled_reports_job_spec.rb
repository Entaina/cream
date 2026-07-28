require "rails_helper"

RSpec.describe ScheduledReportsJob, type: :request do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  def report(schedule:, last_sent_at: nil)
    workspace.reports.create!(
      user: users(:one), name: "R", record_type: "Deal", metric: "count",
      group_by: "stage", date_range: "all", schedule: schedule, last_sent_at: last_sent_at
    )
  end

  it "emails a due scheduled report and stamps last_sent_at" do
    due = report(schedule: "weekly", last_sent_at: 8.days.ago)

    expect { described_class.perform_now }
      .to have_enqueued_mail(ReportMailer, :scheduled_report)
    expect(due.reload.last_sent_at).to be_within(1.minute).of(Time.current)
  end

  it "skips a report whose interval has not elapsed" do
    report(schedule: "weekly", last_sent_at: 1.day.ago)

    expect { described_class.perform_now }.not_to have_enqueued_mail(ReportMailer, :scheduled_report)
  end

  it "skips reports that are not scheduled" do
    report(schedule: "none")

    expect { described_class.perform_now }.not_to have_enqueued_mail(ReportMailer, :scheduled_report)
  end
end
