require "rails_helper"

RSpec.describe Marketing::JourneyRunner do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "journey@example.com") }
  let(:journey) do
    workspace.journeys.create!(name: "Wait test", entry_trigger: "manual", active: true, max_reenrollments: 0)
  end
  let!(:wait_step) do
    journey.steps.create!(position: 0, step_type: "wait", active: true, config: { "minutes" => 5 })
  end
  let!(:next_step) do
    journey.steps.create!(position: 1, step_type: "adjust_score", active: true, config: { "points" => 5 })
  end
  let(:enrollment) do
    JourneyEnrollment.create!(
      workspace: workspace,
      journey: journey,
      person: person,
      current_step: wait_step,
      state: "waiting",
      enrolled_at: 10.minutes.ago,
      next_run_at: 1.minute.ago
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
  end

  it "advances past wait when next_run_at has elapsed" do
    described_class.new(enrollment).advance!

    enrollment.reload
    expect(enrollment.current_step).to eq(next_step)
    expect(enrollment.state).to eq("active")
  end
end
