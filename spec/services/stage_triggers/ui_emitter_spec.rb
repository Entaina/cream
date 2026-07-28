require "rails_helper"

RSpec.describe StageTriggers::UiEmitter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:user) { users(:one) }
  let(:trigger) do
    workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
      execution_mode: "llm", instructions: "x")
  end
  let(:run) { trigger.runs.create!(workspace: workspace, deal: deal, user: user) }
  let(:emitter) { described_class.new(user: user, deal: deal, run: run) }

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_action_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_update_to)
  end

  it "broadcasts a toast to the user's ui stream and records it" do
    emitter.show_toast(message: "Hola", kind: "success")

    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
      .with(user, :ui, target: "toasts", partial: "shared/toast",
        locals: { message: "Hola", kind: "success" })
    expect(run.reload.ui_actions.last).to include("action" => "show_toast")
  end

  it "falls back to info for unknown toast kinds" do
    emitter.show_toast(message: "Hola", kind: "explosive")

    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
      .with(user, :ui, hash_including(locals: { message: "Hola", kind: "info" }))
  end

  it "broadcasts alerts as a custom stream action" do
    emitter.show_alert(message: "Ojo", title: "Aviso")

    expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
      .with(user, :ui, action: "stage_trigger_alert", target: "toasts",
        attributes: { message: "Ojo", title: "Aviso" })
  end

  it "broadcasts confirms with their client-side follow-up" do
    emitter.show_confirm(message: "¿Ver el deal?", follow_up_type: "visit", follow_up_url: "/deals/1")

    expect(Turbo::StreamsChannel).to have_received(:broadcast_action_to)
      .with(user, :ui, action: "stage_trigger_confirm", target: "toasts",
        attributes: hash_including("follow-up-type": "visit", "follow-up-url": "/deals/1"))
  end

  it "rejects external follow-up urls" do
    expect {
      emitter.show_confirm(message: "x", follow_up_type: "visit", follow_up_url: "https://evil.example")
    }.to raise_error(ArgumentError, /internal path/)
  end

  it "rejects unknown follow-up types" do
    expect {
      emitter.show_confirm(message: "x", follow_up_type: "launch_missiles")
    }.to raise_error(ArgumentError, /follow_up_type/)
  end

  it "persists panel content and broadcasts an update to the deal panel" do
    emitter.show_deal_panel(markdown: "**Hola**", title: "Resumen")

    expect(run.reload.panel_markdown).to eq("**Hola**")
    expect(run.panel_title).to eq("Resumen")
    expect(Turbo::StreamsChannel).to have_received(:broadcast_update_to)
      .with(user, :ui, target: "deal_trigger_panel_#{deal.id}",
        partial: "deals/trigger_panel", locals: { deal: deal, run: run })
  end

  context "without a user (MCP/API path)" do
    let(:emitter) { described_class.new(user: nil, deal: deal, run: run) }

    it "records actions without broadcasting" do
      emitter.show_toast(message: "Hola")
      emitter.show_alert(message: "Ojo")
      emitter.show_deal_panel(markdown: "x")

      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_action_to)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_update_to)
      expect(run.reload.ui_actions.size).to eq(3)
      expect(run.panel_markdown).to eq("x")
    end
  end
end
