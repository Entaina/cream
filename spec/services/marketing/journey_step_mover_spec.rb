require "rails_helper"

RSpec.describe Marketing::JourneyStepMover do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "move-step@example.com") }
  let(:journey) do
    workspace.journeys.create!(name: "Nurture", entry_trigger: "manual", active: true, max_reenrollments: 0)
  end
  let!(:first_step) { journey.steps.create!(position: 0, step_type: "wait", active: true, config: { "minutes" => 5 }) }
  let!(:second_step) { journey.steps.create!(position: 1, step_type: "wait", active: true, config: { "minutes" => 10 }) }
  let(:enrollment) do
    JourneyEnrollment.create!(
      workspace: workspace,
      journey: journey,
      person: person,
      current_step: first_step,
      state: "waiting",
      enrolled_at: 2.minutes.ago,
      next_run_at: 3.minutes.from_now
    )
  end

  it "moves an in-progress enrollment to the selected step and makes it due" do
    travel_to Time.zone.parse("2026-09-16 10:00:00") do
      expect(described_class.move!(enrollment: enrollment, step: second_step, actor: users(:one))).to eq(:moved)

      enrollment.reload
      expect(enrollment.current_step).to eq(second_step)
      expect(enrollment.state).to eq("active")
      expect(enrollment.next_run_at).to eq(Time.current)
      expect(enrollment.metadata["manual_moves"].last).to include(
        "from_step_id" => first_step.id,
        "to_step_id" => second_step.id,
        "from_state" => "waiting",
        "actor_id" => users(:one).id
      )
    end
  end

  it "rejects enrollments that are no longer in progress" do
    enrollment.update!(state: "completed", current_step: nil, next_run_at: nil)

    expect(described_class.move!(enrollment: enrollment, step: second_step)).to eq(:not_in_progress)
    expect(enrollment.reload.state).to eq("completed")
  end

  it "rejects steps from another journey" do
    other = workspace.journeys.create!(name: "Other", entry_trigger: "manual", active: true)
    foreign_step = other.steps.create!(position: 0, step_type: "wait", active: true, config: { "minutes" => 1 })

    expect(described_class.move!(enrollment: enrollment, step: foreign_step)).to eq(:invalid_step)
    expect(enrollment.reload.current_step).to eq(first_step)
  end
end
