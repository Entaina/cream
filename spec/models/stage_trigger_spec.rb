require "rails_helper"

RSpec.describe StageTrigger, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.first_stage }

  def build_trigger(**attrs)
    workspace.stage_triggers.new({ name: "Trigger", pipeline_stage: stage,
      execution_mode: "llm", instructions: "Do something" }.merge(attrs))
  end

  it "is valid in llm mode with instructions" do
    expect(build_trigger).to be_valid
  end

  it "requires instructions in llm mode" do
    trigger = build_trigger(instructions: nil)
    expect(trigger).not_to be_valid
    expect(trigger.errors[:instructions]).to be_present
  end

  it "requires a registered native function in native mode" do
    trigger = build_trigger(execution_mode: "native", instructions: nil, native_function: "missing")
    expect(trigger).not_to be_valid
    expect(trigger.errors[:native_function]).to be_present

    trigger.native_function = "won_celebration"
    expect(trigger).to be_valid
  end

  it "does not require instructions in native mode" do
    trigger = build_trigger(execution_mode: "native", instructions: nil,
      native_function: "won_celebration")
    expect(trigger).to be_valid
  end

  it "rejects an unknown execution mode" do
    expect(build_trigger(execution_mode: "magic")).not_to be_valid
  end

  describe "native params" do
    def toast_trigger(**attrs)
      build_trigger(execution_mode: "native", instructions: nil,
        native_function: "show_toast", **attrs)
    end

    it "requires the params declared as required by the function" do
      trigger = toast_trigger(native_params: {})
      expect(trigger).not_to be_valid
      expect(trigger.errors[:native_params].join).to include("Texto")

      trigger.native_params = { "message" => "Hola" }
      expect(trigger).to be_valid
    end

    it "prunes params not declared by the selected function" do
      trigger = toast_trigger(native_params: { "message" => "Hola", "evil" => "x" })
      trigger.valid?
      expect(trigger.native_params).to eq("message" => "Hola")
    end

    it "clears params for functions without params" do
      trigger = build_trigger(execution_mode: "native", instructions: nil,
        native_function: "won_celebration", native_params: { "message" => "sobra" })
      expect(trigger).to be_valid
      expect(trigger.native_params).to eq({})
    end
  end

  it "rejects a stage from another workspace" do
    other_pipeline = Pipeline.create_default!(workspaces(:two))
    trigger = build_trigger(pipeline_stage: other_pipeline.first_stage)
    expect(trigger).not_to be_valid
    expect(trigger.errors[:pipeline_stage]).to be_present
  end

  it "orders and filters active triggers" do
    second = build_trigger(name: "B", position: 1).tap(&:save!)
    first = build_trigger(name: "A", position: 0).tap(&:save!)
    inactive = build_trigger(name: "C", position: 2, active: false).tap(&:save!)

    expect(stage.stage_triggers.active.ordered).to eq([ first, second ])
    expect(stage.stage_triggers.ordered).to eq([ first, second, inactive ])
  end
end
