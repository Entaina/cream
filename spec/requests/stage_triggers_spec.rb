require "rails_helper"

RSpec.describe "StageTriggers", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:stage) { pipeline.first_stage }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(true)
    sign_in_as(member)
  end

  def create_trigger(**attrs)
    workspace.stage_triggers.create!({name: "T", pipeline_stage: stage,
                                      execution_mode: "llm", instructions: "x"}.merge(attrs))
  end

  it "lists the triggers of a stage" do
    create_trigger(name: "Aviso al comercial")
    get pipeline_stage_stage_triggers_path(stage)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Aviso al comercial")
  end

  it "creates an llm trigger" do
    expect {
      post pipeline_stage_stage_triggers_path(stage), params: {
        stage_trigger: {name: "Resumen", execution_mode: "llm", instructions: "Resume el deal", active: "1"}
      }
    }.to change(StageTrigger, :count).by(1)

    trigger = StageTrigger.order(:id).last
    expect(trigger.workspace).to eq(workspace)
    expect(trigger.pipeline_stage).to eq(stage)
    expect(response).to redirect_to(pipeline_stage_stage_triggers_path(stage))
  end

  it "creates a native trigger" do
    post pipeline_stage_stage_triggers_path(stage), params: {
      stage_trigger: {name: "Fiesta", execution_mode: "native", native_function: "won_celebration", active: "1"}
    }
    expect(StageTrigger.order(:id).last.native_function).to eq("won_celebration")
  end

  it "creates a native trigger with params and runs it with them" do
    post pipeline_stage_stage_triggers_path(stage), params: {
      stage_trigger: {name: "Aviso NIF", execution_mode: "native", native_function: "show_toast",
                      native_params: {message: "Pide el NIF", kind: "warning"}, active: "1"}
    }

    trigger = StageTrigger.order(:id).last
    expect(trigger.native_params).to eq("message" => "Pide el NIF", "kind" => "warning")

    ui = instance_double(StageTriggers::UiEmitter, show_toast: nil)
    allow(StageTriggers::UiEmitter).to receive(:new).and_return(ui)
    deal = create_deal!(workspace, pipeline: pipeline)
    run = trigger.runs.create!(workspace: workspace, deal: deal)
    StageTriggers::Runner.call(trigger: trigger, deal: deal, user: member, run: run)

    expect(ui).to have_received(:show_toast).with(message: "Pide el NIF", kind: "warning")
    expect(run.reload.status).to eq("succeeded")
  end

  it "rejects a native trigger missing a required param" do
    post pipeline_stage_stage_triggers_path(stage), params: {
      stage_trigger: {name: "Sin texto", execution_mode: "native", native_function: "show_toast"}
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects an invalid native function and re-renders the form" do
    post pipeline_stage_stage_triggers_path(stage), params: {
      stage_trigger: {name: "Rota", execution_mode: "native", native_function: "nope"}
    }
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "updates and destroys a trigger" do
    trigger = create_trigger
    patch stage_trigger_path(trigger), params: {stage_trigger: {name: "Nuevo nombre"}}
    expect(trigger.reload.name).to eq("Nuevo nombre")

    expect { delete stage_trigger_path(trigger) }.to change(StageTrigger, :count).by(-1)
  end

  it "shows the runs of a trigger" do
    trigger = create_trigger
    deal = create_deal!(workspace, pipeline: pipeline)
    trigger.runs.create!(workspace: workspace, deal: deal, status: "succeeded",
      transcript: [{"type" => "assistant", "content" => "hecho"}])

    get stage_trigger_path(trigger)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("succeeded")
  end

  it "is not reachable when the feature is disabled" do
    allow(CreamFeatures).to receive(:enabled?).with(:stage_triggers).and_return(false)
    get pipeline_stage_stage_triggers_path(stage)
    expect(response).to redirect_to(root_path)
  end

  it "isolates workspaces: a stage from another workspace is not found" do
    other_pipeline = Pipeline.create_default!(workspaces(:two))
    get pipeline_stage_stage_triggers_path(other_pipeline.first_stage)
    expect(response).to have_http_status(:not_found)
  end

  it "isolates workspaces: a trigger from another workspace is not found" do
    other_workspace = workspaces(:two)
    other_pipeline = Pipeline.create_default!(other_workspace)
    foreign = other_workspace.stage_triggers.create!(name: "X", pipeline_stage: other_pipeline.first_stage,
      execution_mode: "llm", instructions: "x")

    get stage_trigger_path(foreign)
    expect(response).to have_http_status(:not_found)
  end
end
