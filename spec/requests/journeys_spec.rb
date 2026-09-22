require "rails_helper"

RSpec.describe "Journeys", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
    sign_in_as(admin)
  end

  it "persists inline email content on send_email steps" do
    post journeys_path, params: {
      journey: {
        name: "Welcome",
        entry_trigger: "manual",
        active: true,
        steps_attributes: {
          "0" => {
            position: "0",
            step_type: "send_email",
            active: "1",
            config: {
              subject: "Hola {first_name}",
              body: "<p>Bienvenida</p>",
              body_editor: "html"
            }
          }
        }
      }
    }

    step = Journey.last.steps.sole
    expect(step.config["subject"]).to eq("Hola {first_name}")
    expect(step.config["body"]).to include("Bienvenida")
    expect(step.config["body_editor"]).to eq("html")
  end

  it "persists 'until time' and 'weekdays only' on wait steps" do
    post journeys_path, params: {
      journey: {
        name: "Timed",
        entry_trigger: "manual",
        active: true,
        steps_attributes: {
          "0" => {
            position: "0",
            step_type: "wait",
            active: "1",
            config: {minutes: "1440", until_time: "10:00", weekdays_only: "1"}
          }
        }
      }
    }

    step = Journey.last.steps.sole
    expect(step.config["until_time"]).to eq("10:00")
    expect(step.config["weekdays_only"]).to eq("1")

    get journey_path(Journey.last)
    expect(response.body).to include("Esperar 1 día y luego hasta las 10:00 (solo días laborables)")
  end

  it "rejects malformed 'until time' values on wait steps" do
    expect {
      post journeys_path, params: {
        journey: {
          name: "Broken",
          entry_trigger: "manual",
          active: true,
          steps_attributes: {
            "0" => {position: "0", step_type: "wait", active: "1", config: {minutes: "5", until_time: "9:30"}}
          }
        }
      }
    }.not_to change(Journey, :count)

    expect(response.body).to include("formato HH:MM")
  end

  describe "manual step change" do
    let(:person) { create_person!(workspace, email: "move-step@example.com") }
    let(:journey) do
      workspace.journeys.create!(name: "Nurture", entry_trigger: "manual", active: true, max_reenrollments: 0)
    end
    let!(:first_step) { journey.steps.create!(position: 0, step_type: "wait", active: true, config: {"minutes" => 5}) }
    let!(:second_step) { journey.steps.create!(position: 1, step_type: "notify", active: true, config: {"message" => "Hola"}) }
    let!(:enrollment) do
      JourneyEnrollment.create!(
        workspace: workspace,
        journey: journey,
        person: person,
        current_step: first_step,
        state: "waiting",
        enrolled_at: Time.current,
        next_run_at: 5.minutes.from_now
      )
    end

    it "lets admins move an enrollment to another step" do
      patch journey_enrollment_path(journey, enrollment), params: {step_id: second_step.id}

      expect(response).to redirect_to(journey)
      follow_redirect!
      expect(response.body).to include(I18n.t("flashes.journey_enrollments.moved", name: person.display_name))
      expect(enrollment.reload.current_step).to eq(second_step)
      expect(enrollment.state).to eq("active")
    end

    it "shows the step mover for in-progress enrollments" do
      get journey_path(journey)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cambiar paso")
      expect(response.body).to include("Mover")
    end

    it "does not move completed enrollments" do
      enrollment.update!(state: "completed", current_step: nil, next_run_at: nil)

      patch journey_enrollment_path(journey, enrollment), params: {step_id: second_step.id}

      expect(response).to redirect_to(journey)
      follow_redirect!
      expect(response.body).to include(I18n.t("flashes.journey_enrollments.not_in_progress"))
      expect(enrollment.reload.state).to eq("completed")
    end

    it "blocks salespeople from changing enrollment steps" do
      sign_in_as(users(:two))
      patch switch_workspace_path, params: {workspace_id: workspace.id}

      patch journey_enrollment_path(journey, enrollment), params: {step_id: second_step.id}

      expect(response).to have_http_status(:not_found)
      expect(enrollment.reload.current_step).to eq(first_step)
    end
  end
end
