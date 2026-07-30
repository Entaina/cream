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
            active: "1"
          }
        }
      }.to change(AlertRule, :count).by(1)

      rule = AlertRule.order(:id).last
      expect(rule.name).to eq("Fin de edición")
      expect(response).to redirect_to(alert_rules_path)
    end

    it "creates an alert rule with nested conditions" do
      expect {
        post alert_rules_path, params: {
          alert_rule: {
            name: "Fin de edición",
            trigger_field: "edition_ends_on",
            offset_days: 0,
            recipient: "deal_owner",
            active: "1",
            alert_conditions_attributes: {
              "0" => { field: "company.fiscal_information", operator: "blank", active: "1" },
              "1" => { field: "open", operator: "eq", compare_value: "true", active: "1" }
            }
          }
        }
      }.to change(AlertRule, :count).by(1)
        .and change(AlertCondition, :count).by(2)

      rule = AlertRule.order(:id).last
      expect(rule.alert_conditions.pluck(:field)).to contain_exactly("company.fiscal_information", "open")
      expect(rule.alert_conditions.map(&:workspace_id).uniq).to eq([ workspace.id ])
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

  describe "PATCH /alert_rules/:id" do
    let!(:rule) do
      workspace.alert_rules.create!(
        name: "Fin de edición",
        trigger_field: "edition_ends_on",
        recipient: "deal_owner"
      )
    end
    let!(:condition) do
      rule.alert_conditions.create!(
        workspace: workspace,
        field: "company.fiscal_information",
        operator: "blank"
      )
    end

    it "updates and removes nested conditions" do
      patch alert_rule_path(rule), params: {
        alert_rule: {
          name: "Fin de edición",
          trigger_field: "edition_ends_on",
          offset_days: 0,
          recipient: "deal_owner",
          active: "1",
          alert_conditions_attributes: {
            "0" => { id: condition.id, field: "company.fiscal_information", operator: "blank", active: "1", _destroy: "1" },
            "1" => { field: "open", operator: "eq", compare_value: "true", active: "1" }
          }
        }
      }

      expect(response).to redirect_to(alert_rules_path)
      expect(rule.reload.alert_conditions.pluck(:field)).to eq([ "open" ])
    end

    it "forbids members from updating alert rules" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      patch alert_rule_path(rule), params: {
        alert_rule: {
          name: "Changed",
          trigger_field: "edition_ends_on",
          recipient: "deal_owner"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(rule.reload.name).to eq("Fin de edición")
    end
  end

  describe "GET /alert_rules/:id/edit" do
    it "renders inline condition fields" do
      rule = workspace.alert_rules.create!(
        name: "Fin de edición",
        trigger_field: "edition_ends_on",
        recipient: "deal_owner"
      )
      rule.alert_conditions.create!(
        workspace: workspace,
        field: "company.fiscal_information",
        operator: "blank"
      )

      get edit_alert_rule_path(rule)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Condiciones adicionales")
      expect(response.body).to include("Añadir condición")
      expect(response.body).to include("company.fiscal_information")
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
