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
end
