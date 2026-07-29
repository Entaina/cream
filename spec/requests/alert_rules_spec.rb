require "rails_helper"

RSpec.describe "AlertRules", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }

  before do
    Pipeline.create_default!(workspace)
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /alert_rules" do
    it "lists alert rules for members" do
      workspace.alert_rules.create!(name: "A", trigger_field: "edition_ends_on", recipient: "deal_owner")

      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }
      get alert_rules_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("A")
    end
  end

  describe "POST /alert_rules" do
    it "creates an alert rule for admins" do
      expect {
        post alert_rules_path, params: {
          alert_rule: {
            name: "Fin de edición",
            trigger_field: "edition_ends_on",
            offset_days: 0,
            recipient: "deal_owner",
            active: "1",
            conditions: [ "company_without_fiscal_info", "" ]
          }
        }
      }.to change(AlertRule, :count).by(1)

      rule = AlertRule.order(:id).last
      expect(rule.conditions).to eq([ "company_without_fiscal_info" ])
      expect(response).to redirect_to(alert_rules_path)
    end

    it "forbids members from creating alert rules" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post alert_rules_path, params: {
          alert_rule: { name: "X", trigger_field: "edition_ends_on", recipient: "deal_owner" }
        }
      }.not_to change(AlertRule, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "when alerts is disabled" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:alerts).and_return(false)
    end

    it "blocks the controller and redirects to root" do
      expect {
        post alert_rules_path, params: {
          alert_rule: { name: "X", trigger_field: "edition_ends_on", recipient: "deal_owner" }
        }
      }.not_to change(AlertRule, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
