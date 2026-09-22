require "rails_helper"

RSpec.describe StageCondition, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: pipeline.first_stage) }

  def build_condition(**attrs)
    workspace.stage_conditions.new({pipeline_stage: stage, field: "value",
                                    operator: "gt", compare_value: "1000"}.merge(attrs))
  end

  describe "validations" do
    it "accepts a valid deal field condition" do
      expect(build_condition).to be_valid
    end

    it "rejects unknown operators" do
      expect(build_condition(operator: "matches")).not_to be_valid
    end

    it "requires compare_value except for blank/present operators" do
      expect(build_condition(compare_value: nil)).not_to be_valid
      expect(build_condition(operator: "blank", compare_value: nil)).to be_valid
      expect(build_condition(operator: "present", compare_value: nil)).to be_valid
    end

    it "rejects a stage from another workspace" do
      other = Pipeline.create_default!(workspaces(:two))
      expect(build_condition(pipeline_stage: other.pipeline_stages.second)).not_to be_valid
    end

    it "rejects custom fields that do not exist in the workspace" do
      expect(build_condition(field: "cf:missing")).not_to be_valid
    end
  end

  describe "#met?" do
    it "evaluates deal numeric comparisons" do
      condition = build_condition(operator: "gt", compare_value: "1000")
      condition.save!
      deal.update_column(:value, 1500)
      expect(condition.met?(deal)).to be(true)

      deal.update_column(:value, 500)
      expect(condition.reload.met?(deal)).to be(false)
    end

    it "evaluates blank and present on deal fields" do
      condition = build_condition(field: "expected_close_date", operator: "blank", compare_value: nil)
      condition.save!
      expect(condition.met?(deal)).to be(true)

      deal.update_column(:expected_close_date, Date.current)
      expect(condition.reload.met?(deal)).to be(false)

      present = workspace.stage_conditions.create!(pipeline_stage: stage, field: "expected_close_date",
        operator: "present", compare_value: nil)
      expect(present.met?(deal)).to be(true)
    end

    it "evaluates company native fields" do
      condition = build_condition(field: "company.industry", operator: "eq", compare_value: "SaaS")
      condition.save!
      deal.company.update!(industry: "SaaS")
      expect(condition.met?(deal)).to be(true)

      deal.company.update!(industry: "Retail")
      expect(condition.reload.met?(deal)).to be(false)
    end

    it "evaluates person fields when any contact matches" do
      deal.contacts.first.update!(email: "pat@example.com")
      condition = build_condition(field: "person.email", operator: "present", compare_value: nil)
      condition.save!
      expect(condition.met?(deal.reload)).to be(true)

      deal.contacts.each { |person| person.update!(email: nil) }
      expect(condition.reload.met?(deal.reload)).to be(false)
    end

    it "treats blank person fields as satisfied when no contact has a value" do
      condition = build_condition(field: "person.phone", operator: "blank", compare_value: nil)
      condition.save!
      deal.contacts.each { |person| person.update!(phone: nil) }
      expect(condition.met?(deal.reload)).to be(true)

      deal.contacts.first.update!(phone: "600000000")
      expect(condition.reload.met?(deal.reload)).to be(false)
    end

    it "evaluates custom fields on deal and company" do
      deal_field = workspace.custom_fields.create!(name: "Tier", field_type: "select",
        record_type: "Deal", options: %w[A B])
      company_field = workspace.custom_fields.create!(name: "Segment", field_type: "text", record_type: "Company")

      deal_condition = workspace.stage_conditions.create!(pipeline_stage: stage, field: "cf:#{deal_field.key}",
        operator: "eq", compare_value: "A")
      company_condition = workspace.stage_conditions.create!(pipeline_stage: stage,
        field: "company.cf:#{company_field.key}", operator: "eq", compare_value: "Enterprise")

      deal.custom_fields = {deal_field.key => "A"}
      deal.save!
      deal.company.custom_fields = {company_field.key => "Enterprise"}
      deal.company.save!

      expect(deal_condition.met?(deal.reload)).to be(true)
      expect(company_condition.met?(deal)).to be(true)
    end

    it "supports contains on text fields" do
      condition = build_condition(field: "name", operator: "contains", compare_value: "annual")
      condition.save!
      deal.update!(name: "Acme — Annual plan")
      expect(condition.met?(deal)).to be(true)
    end

    it "evaluates invoice_number present/blank" do
      condition = build_condition(field: "invoice_number", operator: "present", compare_value: nil)
      condition.save!
      expect(condition.met?(deal)).to be(false)

      deal.update_column(:invoice_number, "FAC-2026-001")
      expect(condition.reload.met?(deal)).to be(true)
    end
  end

  describe ".field_label_for" do
    it "follows the current locale" do
      expect(FieldCondition.field_label_for(workspace, "value")).to eq(I18n.t("activerecord.attributes.deal.value"))
      expect(FieldCondition.operator_label("eq")).to eq(I18n.t("eq", scope: "field_conditions.operators"))

      I18n.with_locale(:en) do
        expect(FieldCondition.field_label_for(workspace, "value")).to eq("Value")
        expect(FieldCondition.operator_label("eq")).to eq("equals")
        expect(FieldCondition.group_label(:deal)).to eq("Deal")
      end
    end
  end

  describe ".field_options" do
    it "includes invoice_number among deal fields" do
      deal_group = described_class.field_options(workspace).find { |label, _| label == FieldCondition.group_label(:deal) }
      keys = deal_group.last.map(&:last)
      expect(keys).to include("invoice_number")
    end
  end

  describe "#describe_requirement" do
    it "phrases the rule as something the deal must satisfy" do
      condition = build_condition(operator: "gt", compare_value: "1000")
      expect(condition.describe_requirement).to eq(
        "#{I18n.t("activerecord.attributes.deal.value")} #{I18n.t("gt", scope: "field_conditions.requirement_operators")} 1000"
      )
    end
  end

  describe "deal stage validation" do
    it "aggregates failed conditions into one error message" do
      build_condition(field: "value", operator: "gt", compare_value: "1000").save!
      build_condition(field: "expected_close_date", operator: "present", compare_value: nil).save!
      deal.update_columns(value: 100, expected_close_date: nil)

      expect {
        deal.move_to_stage!(stage)
      }.to raise_error(ActiveRecord::RecordInvalid) { |error|
        messages = error.record.errors.full_messages
        expect(messages.size).to eq(1)
        blocked = I18n.t("field_conditions.stage_move_blocked", stage: "Qualified", requirements: "*")
        expect(messages.first).to start_with(blocked.split("*").first)
        expect(messages.first).to include(
          "#{I18n.t("activerecord.attributes.deal.value")} #{I18n.t("gt", scope: "field_conditions.requirement_operators")} 1000"
        )
        expect(messages.first).to include(
          "#{I18n.t("activerecord.attributes.deal.expected_close_date")} #{I18n.t("present", scope: "field_conditions.requirement_operators")}"
        )
        expect(messages.first.scan("«Qualified»").size).to eq(1)
      }
    end

    it "blocks moving when conditions fail" do
      build_condition(operator: "gt", compare_value: "1000").save!
      deal.update_column(:value, 100)

      expect {
        deal.move_to_stage!(stage)
      }.to raise_error(ActiveRecord::RecordInvalid)

      expect(deal.reload.pipeline_stage.name).to eq("Lead")
    end

    it "allows moving when all conditions pass" do
      build_condition(operator: "gt", compare_value: "1000").save!
      deal.update_column(:value, 5000)

      expect {
        deal.move_to_stage!(stage)
      }.not_to raise_error

      expect(deal.reload.pipeline_stage).to eq(stage)
    end

    it "ignores inactive conditions" do
      build_condition(active: false, operator: "gt", compare_value: "1000").save!
      deal.update_column(:value, 100)

      expect {
        deal.move_to_stage!(stage)
      }.not_to raise_error
    end
  end
end
