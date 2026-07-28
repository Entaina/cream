require "rails_helper"

RSpec.describe StageTriggers::LlmExecutor do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:user) { users(:one) }
  let(:trigger) do
    workspace.stage_triggers.create!(name: "T", pipeline_stage: pipeline.first_stage,
      execution_mode: "llm", instructions: "Saluda al usuario")
  end
  let(:run) { trigger.runs.create!(workspace: workspace, deal: deal, user: user) }
  let(:ui) { instance_double(StageTriggers::UiEmitter, show_toast: nil, show_alert: nil, show_deal_panel: nil) }
  let(:client) { instance_double(Ai::Client) }

  def executor
    described_class.new(trigger: trigger, deal: deal, user: user, ui: ui, run: run, client: client)
  end

  # Simulates the LLM requesting the given tool calls, then answering.
  def stub_llm(tool_calls, final: "Hecho")
    allow(client).to receive(:chat_with_tools) do |**_kwargs, &block|
      tool_calls.each { |name, args| block.call(name, args) }
      final
    end
  end

  it "sends the trigger instructions and the stage movement as context" do
    stub_llm([])
    executor.call

    expect(client).to have_received(:chat_with_tools) do |system:, input:, tools:, **|
      expect(input).to include(trigger.instructions)
      expect(input).to include(deal.name)
      expect(input).to include(deal.pipeline_stage.name)
      expect(tools.map { |t| t[:name] }).to contain_exactly(
        "get_deal_context", "get_company_context", "get_contact_context",
        "show_toast", "show_alert", "show_confirm", "show_deal_panel")
      true
    end
  end

  it "answers read tools with record context and logs them in the transcript" do
    stub_llm([ [ "get_deal_context", {} ], [ "get_company_context", {} ] ])
    executor.call

    entries = run.reload.transcript
    expect(entries.map { |e| e["name"] }).to include("get_deal_context", "get_company_context")
    expect(entries.first["result_preview"]).to be_present
    expect(entries.last["type"]).to eq("assistant")
  end

  it "delegates UI tools to the emitter" do
    stub_llm([ [ "show_toast", { "message" => "Hola", "kind" => "success" } ],
               [ "show_deal_panel", { "markdown" => "# Hi" } ] ])
    executor.call

    expect(ui).to have_received(:show_toast).with(message: "Hola", kind: "success")
    expect(ui).to have_received(:show_deal_panel).with(markdown: "# Hi")
  end

  it "returns emitter validation errors to the model instead of failing" do
    allow(ui).to receive(:show_confirm).and_raise(ArgumentError, "follow_up_url must be an internal path starting with /")
    results = []
    allow(client).to receive(:chat_with_tools) do |**_kwargs, &block|
      results << block.call("show_confirm", { "message" => "x", "follow_up_type" => "visit", "follow_up_url" => "https://evil" })
      "done"
    end

    executor.call

    expect(results.first).to include("Error: follow_up_url")
    expect(run.reload.transcript.first["error"]).to be_present
  end

  it "resolves contacts only within the deal" do
    stranger = create_person!(workspace)
    results = []
    allow(client).to receive(:chat_with_tools) do |**_kwargs, &block|
      results << block.call("get_contact_context", { "person_id" => stranger.id })
      "done"
    end

    executor.call

    expect(results.first).to eq("El deal no tiene ese contacto.")
  end

  it "does not mutate CRM data when the model calls every tool" do
    real_ui = StageTriggers::UiEmitter.new(user: nil, deal: deal, run: run)
    exec = described_class.new(trigger: trigger, deal: deal, user: nil, ui: real_ui, run: run, client: client)
    stub_llm([ [ "get_deal_context", {} ], [ "get_company_context", {} ], [ "get_contact_context", {} ],
               [ "show_toast", { "message" => "x" } ], [ "show_alert", { "message" => "x" } ],
               [ "show_confirm", { "message" => "x", "follow_up_type" => "toast", "follow_up_message" => "y" } ],
               [ "show_deal_panel", { "markdown" => "z" } ] ])

    deal # fuerza la creación previa
    counts = -> { [ Deal.count, Task.count, Note.count, Person.count, Company.count, Activity.count ] }

    expect { exec.call }.not_to change(&counts)
  end
end
