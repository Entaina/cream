require "rails_helper"

RSpec.describe AlertMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:deal) { create_deal!(workspace) }
  let(:rule) do
    workspace.alert_rules.create!(
      name: "Stale deal",
      trigger_field: "deal_expected_close_date",
      recipient: "deal_owner",
      active: true
    )
  end

  it "sends alert with rule name in subject" do
    mail = described_class.alert_email(user: user, rule: rule, deal: deal)

    expect(mail.to).to eq([user.email_address])
    expect(mail.subject).to include("Stale deal")
  end
end
