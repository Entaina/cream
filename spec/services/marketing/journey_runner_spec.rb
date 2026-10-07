require "rails_helper"

RSpec.describe Marketing::JourneyRunner do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "journey@example.com") }
  let(:journey) do
    workspace.journeys.create!(name: "Wait test", entry_trigger: "manual", active: true, max_reenrollments: 0)
  end
  let!(:wait_step) do
    journey.steps.create!(position: 0, step_type: "wait", active: true, config: {"minutes" => 5})
  end
  let!(:second_wait_step) do
    journey.steps.create!(position: 1, step_type: "wait", active: true, config: {"minutes" => 10})
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
  end

  describe "wait step" do
    it "schedules next_run_at on first arrival without advancing" do
      enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: person,
        current_step: wait_step,
        state: "active",
        enrolled_at: Time.current,
        next_run_at: Time.current
      )

      travel_to Time.zone.parse("2026-09-16 10:00:00") do
        described_class.new(enrollment).advance!

        enrollment.reload
        expect(enrollment.current_step).to eq(wait_step)
        expect(enrollment.state).to eq("waiting")
        expect(enrollment.next_run_at).to eq(5.minutes.from_now)
      end
    end

    it "schedules 'until time' waits in the workspace zone" do
      workspace.update!(time_zone: "Europe/Madrid")
      wait_step.update!(config: {"minutes" => 0, "until_time" => "10:00", "weekdays_only" => "1"})
      enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: person,
        current_step: wait_step,
        state: "active",
        enrolled_at: Time.current,
        next_run_at: Time.current
      )

      # Friday 18 Sep 2026, 12:00 UTC (14:00 Madrid): 10:00 already passed, weekend skipped.
      travel_to Time.find_zone("UTC").local(2026, 9, 18, 12, 0) do
        Time.use_zone("America/New_York") { described_class.new(enrollment).advance! }
      end

      enrollment.reload
      expect(enrollment.state).to eq("waiting")
      expect(enrollment.next_run_at).to eq(ActiveSupport::TimeZone["Europe/Madrid"].local(2026, 9, 21, 10, 0))
    end

    it "does not reset next_run_at while still pending" do
      scheduled_at = 3.minutes.from_now
      enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: person,
        current_step: wait_step,
        state: "waiting",
        enrolled_at: 2.minutes.ago,
        next_run_at: scheduled_at
      )

      described_class.new(enrollment).advance!

      enrollment.reload
      expect(enrollment.current_step).to eq(wait_step)
      expect(enrollment.state).to eq("waiting")
      expect(enrollment.next_run_at).to be_within(1.second).of(scheduled_at)
    end

    it "advances past wait when next_run_at has elapsed" do
      travel_to Time.zone.parse("2026-09-16 10:00:00") do
        enrollment = JourneyEnrollment.create!(
          workspace: workspace,
          journey: journey,
          person: person,
          current_step: wait_step,
          state: "waiting",
          enrolled_at: 10.minutes.ago,
          next_run_at: 1.minute.ago
        )

        described_class.new(enrollment).advance!

        enrollment.reload
        expect(enrollment.current_step).to eq(second_wait_step)
        expect(enrollment.state).to eq("waiting")
        expect(enrollment.next_run_at).to eq(10.minutes.from_now)
      end
    end

    it "sends email in the same tick when wait is followed by send_email" do
      esp_double = instance_double(Marketing::Esp::SmtpAdapter, deliver!: true)
      allow(Marketing::Esp::Client).to receive(:for).and_return(esp_double)
      SubscriptionType.ensure_defaults!(workspace)
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person,
        subscription_type: type,
        source: "spec",
        legal_basis: "consent"
      )

      email_journey = workspace.journeys.create!(name: "Wait then email", entry_trigger: "manual", active: true, max_reenrollments: 0)
      email_journey.steps.destroy_all
      email_journey.steps.create!(position: 0, step_type: "wait", active: true, config: {"minutes" => 5})
      email_journey.steps.create!(
        position: 1,
        step_type: "send_email",
        active: true,
        config: {
          "subject" => "Journey {first_name}",
          "body" => "<p>Hola {first_name}</p>",
          "body_editor" => "html"
        }
      )
      after_email_step = email_journey.steps.create!(position: 2, step_type: "wait", active: true, config: {"minutes" => 1})

      enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: email_journey,
        person: person,
        current_step: email_journey.steps.ordered.first,
        state: "waiting",
        enrolled_at: 10.minutes.ago,
        next_run_at: 1.minute.ago
      )

      described_class.new(enrollment).advance!

      expect(esp_double).to have_received(:deliver!).once
      enrollment.reload
      expect(enrollment.current_step).to eq(after_email_step)
      expect(enrollment.state).to eq("active")
    end
  end

  describe ".run!" do
    let!(:adjust_step) do
      journey.steps.create!(position: 2, step_type: "adjust_score", active: true, config: {"points" => 5})
    end

    it "continues processing other enrollments when one raises" do
      bad_person = create_person!(workspace, email: "bad@example.com")
      good_person = create_person!(workspace, email: "good@example.com")

      bad_enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: bad_person,
        current_step: adjust_step,
        state: "active",
        enrolled_at: Time.current,
        next_run_at: Time.current
      )
      good_enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: good_person,
        current_step: adjust_step,
        state: "active",
        enrolled_at: Time.current,
        next_run_at: Time.current
      )

      allow(JourneyEnrollment).to receive(:due).and_return(JourneyEnrollment.where(id: [bad_enrollment.id, good_enrollment.id]))
      call_count = 0
      allow_any_instance_of(described_class).to receive(:advance!) do |runner|
        call_count += 1
        raise StandardError, "boom" if runner.send(:enrollment).id == bad_enrollment.id
      end

      described_class.run!

      expect(call_count).to eq(2)
      expect(bad_enrollment.reload.metadata.dig("last_error", "message")).to eq("boom")
    end

    it "computes task due dates on the workspace's calendar day" do
      workspace.update!(time_zone: "Europe/Madrid")
      task_step = journey.steps.create!(
        position: 3, step_type: "create_task", active: true, config: {"title" => "Follow up", "due_days" => 1}
      )
      enrollment = JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: person,
        current_step: task_step,
        state: "active",
        enrolled_at: Time.current,
        next_run_at: Time.current
      )
      allow(JourneyEnrollment).to receive(:due).and_return(JourneyEnrollment.where(id: enrollment.id))

      # 23:30 UTC on the 16th is already 01:30 on the 17th in Madrid.
      travel_to Time.find_zone("UTC").local(2026, 9, 16, 23, 30) do
        described_class.run!
      end

      expect(person.tasks.order(:id).last.due_on).to eq(Date.new(2026, 9, 18))
    end
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

    it "does not advance when delivery fails" do
      allow(esp_double).to receive(:deliver!).and_return(false)

      described_class.new(email_enrollment).advance!

      email_enrollment.reload
      message = workspace.email_messages.where(marketing_send: true).order(:id).last
      expect(email_enrollment.current_step).to eq(email_step)
      expect(email_enrollment.state).to eq("active")
      expect(email_enrollment.metadata.dig("last_error", "message")).to eq("delivery_failed")
      expect(message.status).to eq("failed")
    end

    it "records errors from message creation without advancing" do
      allow(workspace.email_messages).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

      described_class.new(email_enrollment).advance!

      email_enrollment.reload
      expect(email_enrollment.current_step).to eq(email_step)
      expect(email_enrollment.metadata["step_errors"]).to be_present
    end
  end

  describe "set_field step" do
    it "labels the lifecycle change activity with the journey name" do
      field_step = journey.steps.create!(
        position: 2, step_type: "set_field", active: true,
        config: {"field" => "lifecycle_stage", "value" => "lead"}
      )
      enrollment = JourneyEnrollment.create!(
        workspace: workspace, journey: journey, person: person, current_step: field_step,
        state: "active", enrolled_at: Time.current, next_run_at: Time.current
      )
      person.activities.delete_all

      described_class.new(enrollment).advance!

      activity = person.activities.find_by!(action: "updated")
      expect(activity.user).to be_nil
      expect(activity.metadata["automation"]).to eq({"kind" => "journey", "name" => "Wait test"})
      expect(Current.automation).to be_nil
    end
  end
end
