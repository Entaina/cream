require "rails_helper"

RSpec.describe AlertCondition, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:rule) do
    workspace.alert_rules.create!(
      name: "Test",
      trigger_field: "edition_ends_on",
      recipient: "deal_owner"
    )
  end
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: pipeline.first_stage) }

  def build_condition(**attrs)
    workspace.alert_conditions.new({ alert_rule: rule, field: "value",
      operator: "gt", compare_value: "1000" }.merge(attrs))
  end

  describe "validations" do
    it "accepts a valid deal field condition" do
      expect(build_condition).to be_valid
    end

    it "rejects an alert rule from another workspace" do
      other_rule = workspaces(:two).alert_rules.create!(
        name: "Other",
        trigger_field: "edition_ends_on",
        recipient: "deal_owner"
      )
      expect(build_condition(alert_rule: other_rule)).not_to be_valid
    end

    it "inherits workspace from the alert rule" do
      condition = rule.alert_conditions.build(field: "value", operator: "gt", compare_value: "1000")
      condition.valid?
      expect(condition.workspace).to eq(workspace)
    end

    it "evaluates company fiscal information blank" do
      condition = build_condition(field: "company.fiscal_information", operator: "blank", compare_value: nil)
      condition.save!
      deal.company.update!(fiscal_information: nil)
      expect(condition.met?(deal)).to be(true)

      deal.company.update!(fiscal_information: "CIF B12345678")
      expect(condition.reload.met?(deal)).to be(false)
    end

    it "evaluates deal open state" do
      condition = build_condition(field: "open", operator: "eq", compare_value: "true")
      condition.save!
      expect(condition.met?(deal)).to be(true)

      closed_stage = pipeline.pipeline_stages.find_by!(closed: true)
      deal.update!(pipeline_stage: closed_stage)
      expect(condition.reload.met?(deal)).to be(false)
    end
  end
end
