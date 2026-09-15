require "rails_helper"

RSpec.describe "Automations", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before { sign_in_as(member) }

  describe "POST /automations" do
    it "creates an automation and builds trigger_conditions from the condition rows" do
      expect {
        post automations_path, params: {
          automation: {
            name: "Won deals → task", trigger_event: "deal.stage_changed",
            action_type: "create_task", active: "1",
            condition_keys: ["to", ""], condition_values: ["Won", ""],
            action_params: {title: "Celebrate", due_on: "2026-07-01"}
          }
        }
      }.to change(Automation, :count).by(1)

      automation = Automation.order(:id).last
      expect(automation.trigger_conditions).to eq("to" => "Won")
      expect(automation.action_params).to include("title" => "Celebrate", "due_on" => "2026-07-01")
      expect(response).to redirect_to(automations_path)
    end

    it "updates trigger_conditions, dropping rows with a blank key" do
      automation = workspace.automations.create!(name: "A", trigger_event: "record.created",
        action_type: "create_task", trigger_conditions: {"old" => "x"})

      patch automation_path(automation), params: {
        automation: {
          name: "A", trigger_event: "record.created", action_type: "create_task",
          condition_keys: ["industry", ""], condition_values: ["SaaS", "ignored"]
        }
      }

      expect(automation.reload.trigger_conditions).to eq("industry" => "SaaS")
    end
  end

  describe "engine hook" do
    it "enqueues AutomationJob when a record is created" do
      expect { workspace.companies.create!(name: "Hooked Co") }
        .to have_enqueued_job(AutomationJob).with("record.created", anything, {})
    end
  end

  describe "when automations is disabled" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:automations).and_return(false)
    end

    it "blocks the controller and redirects to root" do
      expect {
        post automations_path, params: {
          automation: {name: "X", trigger_event: "record.created", action_type: "create_task"}
        }
      }.not_to change(Automation, :count)

      expect(response).to redirect_to(root_path)
    end
  end
end
