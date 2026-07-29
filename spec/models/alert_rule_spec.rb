require "rails_helper"

RSpec.describe AlertRule, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  it "is valid with defaults" do
    rule = workspace.alert_rules.new(
      name: "Test",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner"
    )
    expect(rule).to be_valid
  end

  it "rejects unknown trigger fields" do
    rule = workspace.alert_rules.new(name: "Test", trigger_field: "invalid", recipient: "deal_owner")
    expect(rule).not_to be_valid
  end

  it "rejects unknown conditions" do
    rule = workspace.alert_rules.new(
      name: "Test",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner",
      conditions: [ "unknown" ]
    )
    expect(rule).not_to be_valid
  end

  it "accepts known conditions" do
    rule = workspace.alert_rules.new(
      name: "Test",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner",
      conditions: %w[company_without_fiscal_info deal_open]
    )
    expect(rule).to be_valid
  end
end
