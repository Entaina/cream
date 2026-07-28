require "rails_helper"

RSpec.describe StageTriggerJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:user) { users(:one) }
  let(:trigger) do
    workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
      execution_mode: "native", native_function: "won_celebration")
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(true)
  end

  it "creates a run and executes the native handler" do
    allow(StageTriggers::Native::WonCelebration).to receive(:call)

    expect { described_class.perform_now(trigger, deal, user) }.to change(StageTriggerRun, :count).by(1)

    run = trigger.runs.last
    expect(run.status).to eq("succeeded")
    expect(run.user).to eq(user)
    expect(run.transcript).to include("type" => "native_call", "function" => "won_celebration")
    expect(StageTriggers::Native::WonCelebration).to have_received(:call)
      .with(hash_including(deal: deal, user: user, trigger: trigger))
  end

  it "marks the run as failed when the handler raises, without re-raising" do
    allow(StageTriggers::Native::WonCelebration).to receive(:call).and_raise("boom")

    expect { described_class.perform_now(trigger, deal, user) }.not_to raise_error

    run = trigger.runs.last
    expect(run.status).to eq("failed")
    expect(run.error).to include("boom")
  end

  it "does nothing when the trigger is inactive" do
    trigger.update!(active: false)
    expect { described_class.perform_now(trigger, deal, user) }.not_to change(StageTriggerRun, :count)
  end

  it "does nothing when the feature is disabled" do
    allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(false)
    expect { described_class.perform_now(trigger, deal, user) }.not_to change(StageTriggerRun, :count)
  end
end
