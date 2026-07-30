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

  it "destroys associated alert conditions" do
    rule = workspace.alert_rules.create!(
      name: "Test",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner"
    )
    rule.alert_conditions.create!(
      workspace: workspace,
      field: "company.fiscal_information",
      operator: "blank"
    )

    expect { rule.destroy }.to change(AlertCondition, :count).by(-1)
  end
end
