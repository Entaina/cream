require "rails_helper"

RSpec.describe StageTriggerRun, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:trigger) do
    workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
      execution_mode: "llm", instructions: "x")
  end

  def create_run(**attrs)
    trigger.runs.create!({workspace: workspace, deal: deal}.merge(attrs))
  end

  it "walks the status lifecycle and measures duration" do
    run = create_run
    expect(run.status).to eq("pending")

    run.start!
    expect(run.status).to eq("running")

    run.succeed!
    expect(run.reload.status).to eq("succeeded")
    expect(run.duration).to be >= 0
  end

  it "records failures with a truncated message" do
    run = create_run
    run.fail!("boom " * 1000)
    expect(run.status).to eq("failed")
    expect(run.error.length).to be <= 2000
  end

  it "returns the latest run with panel content for a deal" do
    create_run(panel_markdown: "old", created_at: 2.hours.ago)
    latest = create_run(panel_markdown: "new", created_at: 1.hour.ago)
    create_run # sin panel

    expect(described_class.latest_panel_for(deal)).to eq(latest)
  end

  it "allows a run without user (MCP/API path)" do
    expect(create_run(user: nil)).to be_persisted
  end
end
