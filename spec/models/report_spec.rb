require "rails_helper"

RSpec.describe Report, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  it "validates metric and group_by for record type" do
    report = workspace.reports.new(
      user: user,
      name: "Deals by stage",
      record_type: "Deal",
      metric: "count",
      group_by: "stage",
      date_range: "month",
      schedule: "none"
    )

    expect(report).to be_valid
    expect(report.scheduled?).to be false
  end

  it "knows when a scheduled report is due" do
    report = workspace.reports.create!(
      user: user,
      name: "Weekly",
      record_type: "Person",
      metric: "count",
      group_by: "month",
      date_range: "month",
      schedule: "weekly"
    )

    expect(report.due_to_send?).to be true
    report.update!(last_sent_at: Time.current)
    expect(report.due_to_send?).to be false
  end
end
