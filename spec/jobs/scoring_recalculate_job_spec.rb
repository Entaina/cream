require "rails_helper"

RSpec.describe ScoringRecalculateJob, type: :job do
  fixtures :workspaces

  it "recalculates scores for one workspace" do
    workspace = workspaces(:one)
    allow(Marketing::ScoringEngine).to receive(:recalculate!)

    described_class.perform_now(workspace.id)

    expect(Marketing::ScoringEngine).to have_received(:recalculate!).with(workspace)
  end
end
