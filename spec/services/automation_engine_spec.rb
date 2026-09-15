require "rails_helper"

RSpec.describe AutomationEngine, type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "p@example.com") }

  def automation(attrs = {})
    workspace.automations.create!({
      name: "A", trigger_event: "record.created", action_type: "create_task", active: true
    }.merge(attrs))
  end

  describe ".conditions_match?" do
    it "matches metadata and record attributes by string equality" do
      auto = automation(trigger_event: "deal.stage_changed", trigger_conditions: {"to" => "Won"})

      expect(described_class.conditions_match?(auto, person, {"to" => "Won"})).to be(true)
      expect(described_class.conditions_match?(auto, person, {"to" => "Lost"})).to be(false)
    end

    it "is true when there are no conditions" do
      expect(described_class.conditions_match?(automation(trigger_conditions: {}), person, {})).to be(true)
    end
  end

  describe ".run" do
    it "runs create_task for a matching automation" do
      automation(action_type: "create_task", action_params: {"title" => "Welcome call"})

      expect { described_class.run(event: "record.created", record: person) }
        .to change { person.tasks.count }.by(1)
      expect(person.tasks.last.title).to eq("Welcome call")
    end

    it "skips automations whose conditions do not match" do
      automation(trigger_event: "deal.stage_changed", trigger_conditions: {"to" => "Won"})

      expect {
        described_class.run(event: "deal.stage_changed", record: person, metadata: {"to" => "Lost"})
      }.not_to change(Task, :count)
    end

    context "send_email action with record_email enabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      end

      it "enqueues an email to the record" do
        automation(action_type: "send_email", action_params: {"subject" => "Hi", "body" => "Yo"})

        expect { described_class.run(event: "record.created", record: person) }
          .to have_enqueued_mail(RecordMailer, :record_email)
      end
    end

    context "notify_slack action with slack disabled" do
      before do
        allow(CreamFeatures).to receive(:enabled?).and_call_original
        allow(CreamFeatures).to receive(:enabled?).with(:slack_integrations).and_return(false)
      end

      it "does nothing and does not call the notifier" do
        automation(action_type: "notify_slack")
        expect(SlackNotifier).not_to receive(:notify)

        expect { described_class.run(event: "record.created", record: person) }.not_to raise_error
      end
    end
  end
end
