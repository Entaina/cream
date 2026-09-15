require "rails_helper"

RSpec.describe StageFieldFormat, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.first_stage }
  let(:deal) { create_deal!(workspace, pipeline: pipeline, stage: stage) }

  def build_format(**attrs)
    workspace.stage_field_formats.new({pipeline_stage: stage, field: "value",
                                       operator: "eq", compare_value: "0", display_text: "guest"}.merge(attrs))
  end

  describe "validations" do
    it "accepts the guest example" do
      expect(build_format).to be_valid
    end

    it "rejects unknown fields and operators" do
      expect(build_format(field: "name")).not_to be_valid
      expect(build_format(operator: "matches")).not_to be_valid
    end

    it "requires display_text" do
      expect(build_format(display_text: "")).not_to be_valid
    end

    it "requires compare_value except for the blank operator" do
      expect(build_format(compare_value: nil)).not_to be_valid
      expect(build_format(operator: "blank", compare_value: nil)).to be_valid
    end

    it "rejects a stage from another workspace" do
      other = Pipeline.create_default!(workspaces(:two))
      expect(build_format(pipeline_stage: other.first_stage)).not_to be_valid
    end
  end

  describe ".display_for" do
    it "returns the text when price is zero (guest example)" do
      build_format.save!
      deal.update_column(:value, 0)

      expect(described_class.display_for(deal, :value)).to eq("guest")
    end

    it "returns nil when the condition does not match" do
      build_format.save!
      deal.update_column(:value, 500)

      expect(described_class.display_for(deal, :value)).to be_nil
    end

    it "only applies on the configured stage" do
      build_format.save!
      deal.update_column(:value, 0)
      deal.move_to_stage!("Qualified")

      expect(described_class.display_for(deal.reload, :value)).to be_nil
    end

    it "ignores inactive rules and picks the first active match" do
      build_format(display_text: "apagado", active: false, position: 0).save!
      build_format(display_text: "guest", position: 1).save!
      build_format(display_text: "segunda", position: 2).save!
      deal.update_column(:value, 0)

      expect(described_class.display_for(deal, :value)).to eq("guest")
    end

    it "supports lt/gt comparisons" do
      build_format(operator: "lt", compare_value: "100", display_text: "low").save!
      deal.update_column(:value, 50)
      expect(described_class.display_for(deal, :value)).to eq("low")

      deal.update_column(:value, 150)
      expect(described_class.display_for(deal, :value)).to be_nil
    end

    it "supports blank on dates" do
      build_format(field: "expected_close_date", operator: "blank", compare_value: nil,
        display_text: "sin fecha").save!

      expect(described_class.display_for(deal, :expected_close_date)).to eq("sin fecha")

      deal.update_column(:expected_close_date, Date.current)
      expect(described_class.display_for(deal, :expected_close_date)).to be_nil
    end

    it "does not match when compare_value is not parseable" do
      build_format(field: "expected_close_date", operator: "eq", compare_value: "not-a-date",
        display_text: "x").save!
      deal.update_column(:expected_close_date, Date.current)

      expect(described_class.display_for(deal, :expected_close_date)).to be_nil
    end
  end
end
