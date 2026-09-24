require "rails_helper"

RSpec.describe "ScoringRules", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    workspace.update!(lead_scoring_enabled: true)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:lead_scoring).and_return(true)
    sign_in_as(admin)
  end

  it "creates a scoring rule" do
    expect {
      post scoring_rules_path, params: {
        scoring_rule: {name: "Opened email", event_type: "email_opened", points: 10, active: true}
      }
    }.to change(ScoringRule, :count).by(1)

    expect(response).to redirect_to(scoring_rules_path)
  end

  it "updates a scoring rule" do
    rule = workspace.scoring_rules.create!(name: "Old", points: 5, active: true)

    patch scoring_rule_path(rule), params: {scoring_rule: {name: "New", points: 15}}

    expect(response).to redirect_to(scoring_rules_path)
    expect(rule.reload.name).to eq("New")
  end

  it "forbids non-admin members" do
    sign_in_as(salesperson)
    patch switch_workspace_path, params: {workspace_id: workspace.id}

    expect {
      post scoring_rules_path, params: {
        scoring_rule: {name: "X", points: 1, active: true}
      }
    }.not_to change(ScoringRule, :count)

    expect(response).to redirect_to(root_path)
  end
end
