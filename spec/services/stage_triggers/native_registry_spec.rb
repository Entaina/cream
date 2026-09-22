require "rails_helper"

RSpec.describe StageTriggers::NativeRegistry do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:user) { users(:one) }
  let(:trigger) do
    workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
      execution_mode: "native", native_function: "won_celebration")
  end
  let(:ui) { instance_double(StageTriggers::UiEmitter) }

  it "resolves every registered handler to a callable class" do
    described_class.keys.each do |key|
      handler = described_class.handler_for(key)
      expect(handler).to respond_to(:call)
    end
  end

  it "raises for unknown keys" do
    expect { described_class.fetch("missing") }.to raise_error(KeyError)
  end

  it "localizes registry labels per locale" do
    I18n.with_locale(:es) do
      expect(described_class.fetch("show_toast").label).to eq("Mostrar toast")
      expect(described_class.fetch("show_toast").params.first.label).to eq("Texto")
    end
    I18n.with_locale(:en) do
      expect(described_class.fetch("show_toast").label).to eq("Show toast")
      expect(described_class.fetch("show_toast").params.first.label).to eq("Text")
    end
  end

  describe "won_celebration" do
    it "shows a success toast with the deal name and value" do
      deal.update_column(:value, 5000)
      allow(ui).to receive(:show_toast)

      described_class.handler_for("won_celebration").call(deal: deal, user: user, trigger: trigger, ui: ui)

      expect(ui).to have_received(:show_toast).with(
        message: I18n.t("stage_triggers.native_handlers.won_celebration.message_with_value",
          name: deal.name,
          amount: ApplicationController.helpers.money(deal.value, deal.currency)),
        kind: "success"
      )
    end

    it "localizes the celebration message" do
      allow(ui).to receive(:show_toast)

      I18n.with_locale(:en) do
        described_class.handler_for("won_celebration").call(deal: deal, user: user, trigger: trigger, ui: ui)
      end

      expect(ui).to have_received(:show_toast).with(
        message: I18n.t("stage_triggers.native_handlers.won_celebration.message", locale: :en, name: deal.name),
        kind: "success"
      )
    end
  end

  describe "show_toast" do
    it "declares its params for the dynamic form" do
      entry = described_class.fetch("show_toast")
      expect(entry.params.map(&:key)).to eq(%w[message kind])
      expect(entry.params.first.required).to be(true)
    end

    it "shows a toast with the configured text and kind" do
      allow(ui).to receive(:show_toast)

      described_class.handler_for("show_toast").call(deal: deal, user: user, trigger: trigger, ui: ui,
        params: {"message" => "Pide el NIF", "kind" => "warning"})

      expect(ui).to have_received(:show_toast).with(message: "Pide el NIF", kind: "warning")
    end

    it "defaults to info kind when not configured" do
      allow(ui).to receive(:show_toast)

      described_class.handler_for("show_toast").call(deal: deal, user: user, trigger: trigger, ui: ui,
        params: {"message" => "Hola"})

      expect(ui).to have_received(:show_toast).with(message: "Hola", kind: "info")
    end
  end

  describe "stage_checklist_panel" do
    it "shows a panel listing pending tasks of the deal" do
      allow(ui).to receive(:show_deal_panel)
      task = deal.tasks.pending.order(:due_on).first

      described_class.handler_for("stage_checklist_panel").call(deal: deal, user: user, trigger: trigger, ui: ui)

      expect(ui).to have_received(:show_deal_panel).with(
        title: I18n.t("stage_triggers.native_handlers.stage_checklist_panel.title",
          stage: deal.pipeline_stage.name),
        markdown: a_string_including(
          I18n.t("stage_triggers.native_handlers.stage_checklist_panel.pending_tasks"),
          task.title
        )
      )
    end

    it "localizes the checklist copy" do
      allow(ui).to receive(:show_deal_panel)
      task = deal.tasks.pending.order(:due_on).first

      I18n.with_locale(:en) do
        described_class.handler_for("stage_checklist_panel").call(deal: deal, user: user, trigger: trigger, ui: ui)
      end

      expect(ui).to have_received(:show_deal_panel).with(
        title: I18n.t("stage_triggers.native_handlers.stage_checklist_panel.title",
          locale: :en, stage: deal.pipeline_stage.name),
        markdown: a_string_including(
          I18n.t("stage_triggers.native_handlers.stage_checklist_panel.pending_tasks", locale: :en),
          task.title
        )
      )
    end
  end
end
