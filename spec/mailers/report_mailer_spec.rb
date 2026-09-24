require "rails_helper"

RSpec.describe ReportMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "sends scheduled report to owner" do
    report = workspace.reports.create!(
      user: user,
      name: "Weekly deals",
      record_type: "Deal",
      metric: "count",
      group_by: "stage",
      date_range: "month",
      schedule: "weekly"
    )
    result = ReportRunner::Result.new(rows: [], metric: "count", metric_label: "Count", total: 0, max: 0, all_pipelines_stage_chart: false)
    allow(ReportRunner).to receive(:new).and_return(instance_double(ReportRunner, run: result))

    mail = described_class.scheduled_report(report)

    expect(mail.to).to eq([user.email_address])
    expect(mail.subject).to include("Weekly deals")
  end
end
