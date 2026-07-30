require "rails_helper"

RSpec.describe "AlertConditions", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let!(:alert_rule) do
    workspace.alert_rules.create!(
      name: "Fin de edición",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner"
    )
  end

  before do
    Pipeline.create_default!(workspace)
    sign_in_as(admin)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  def create_condition(**attrs)
    workspace.alert_conditions.create!({ alert_rule: alert_rule, field: "value",
      operator: "gt", compare_value: "1000" }.merge(attrs))
  end

  it "lists the conditions of an alert rule" do
    create_condition
    get alert_rule_alert_conditions_path(alert_rule)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Valor")
  end

  it "creates a condition" do
    expect {
      post alert_rule_alert_conditions_path(alert_rule), params: {
        alert_condition: { field: "company.fiscal_information", operator: "blank", active: "1" }
      }
    }.to change(AlertCondition, :count).by(1)

    condition = AlertCondition.order(:id).last
    expect(condition.workspace).to eq(workspace)
    expect(condition.alert_rule).to eq(alert_rule)
  end

  it "rejects an invalid condition" do
    post alert_rule_alert_conditions_path(alert_rule), params: {
      alert_condition: { field: "value", operator: "gt", compare_value: "" }
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates and destroys a condition" do
    condition = create_condition
    patch alert_condition_path(condition), params: { alert_condition: { compare_value: "2000" } }
    expect(condition.reload.compare_value).to eq("2000")

    expect { delete alert_condition_path(condition) }.to change(AlertCondition, :count).by(-1)
  end

  it "forbids members from creating conditions" do
    sign_in_as(member)
    patch switch_workspace_path, params: { workspace_id: workspace.id }

    expect {
      post alert_rule_alert_conditions_path(alert_rule), params: {
        alert_condition: { field: "value", operator: "gt", compare_value: "1000", active: "1" }
      }
    }.not_to change(AlertCondition, :count)

    expect(response).to redirect_to(root_path)
  end

  it "isolates workspaces" do
    other_rule = workspaces(:two).alert_rules.create!(
      name: "Other",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner"
    )
    get alert_rule_alert_conditions_path(other_rule)
    expect(response).to have_http_status(:not_found)
  end
end
