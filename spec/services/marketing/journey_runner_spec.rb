require "rails_helper"

RSpec.describe Marketing::JourneyRunner do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "journey@example.com") }
  let(:journey) do
    workspace.journeys.create!(name: "Wait test", entry_trigger: "manual", active: true, max_reenrollments: 0)
  end
  let!(:wait_step) do
    journey.steps.create!(position: 0, step_type: "wait", active: true, config: {"minutes" => 5})
  end
  let!(:next_step) do
    journey.steps.create!(position: 1, step_type: "adjust_score", active: true, config: {"points" => 5})
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

  describe "send_email step" do
    let(:esp_double) { instance_double(Marketing::Esp::SmtpAdapter, deliver!: true) }
    let(:email_journey) do
      workspace.journeys.create!(name: "Email", entry_trigger: "manual", active: true, max_reenrollments: 0)
    end
    let!(:email_step) do
      email_journey.steps.create!(
        position: 0,
        step_type: "send_email",
        active: true,
        config: {
          "subject" => "Journey {first_name}",
          "body" => "<p>Hola {first_name}</p>",
          "body_editor" => "html"
        }
      )
    end
    let!(:after_email_step) do
      email_journey.steps.create!(position: 1, step_type: "wait", active: true, config: {"minutes" => 1})
    end
    let(:email_enrollment) do
      JourneyEnrollment.create!(
        workspace: workspace,
        journey: email_journey,
        person: person,
        current_step: email_step,
        state: "active",
        enrolled_at: Time.current
      )
    end

    before do
      allow(Marketing::Esp::Client).to receive(:for).and_return(esp_double)
      SubscriptionType.ensure_defaults!(workspace)
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person,
        subscription_type: type,
        source: "spec",
        legal_basis: "consent"
      )
    end

    it "sends using inline step content" do
      described_class.new(email_enrollment).advance!

      expect(esp_double).to have_received(:deliver!).once
      message = workspace.email_messages.where(marketing_send: true).order(:id).last
      expect(message.subject).to eq("Journey Pat")
      expect(message.body).to include("Hola Pat")
      expect(email_enrollment.reload.current_step).to eq(after_email_step)
    end

    it "skips when step has no email content" do
      email_step.update!(config: {})
      described_class.new(email_enrollment).advance!

      expect(esp_double).not_to have_received(:deliver!)
      expect(email_enrollment.reload.current_step).to eq(after_email_step)
    end
  end
end
