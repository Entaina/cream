require "rails_helper"

RSpec.describe "OKM chat", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }
  let(:other_workspace) { workspaces(:two) }
  let(:other_company) { companies(:globex) }
  let(:agent_result) do
    Ai::ContextualAgent::Result.new(
      reply: "Contexto relevante de ventas.",
      pending_actions: pending_actions,
      session_id: "sess-test"
    )
  end
  let(:pending_actions) { [] }
  let(:chat_agent) { instance_double(Ai::ContextualAgent, call: agent_result) }

  def parse_stream(body)
    body.to_s.split("\n").filter_map { |line| JSON.parse(line) if line.present? }
  end

  let(:okm_service_account_key) do
    {
      "type" => "service_account",
      "project_id" => "test-project",
      "private_key_id" => "key123",
      "private_key" => "-----BEGIN PRIVATE KEY-----\ntest\n-----END PRIVATE KEY-----\n",
      "client_email" => "okm@test.iam.gserviceaccount.com",
      "client_id" => "123456789"
    }.to_json
  end

  before do
    sign_in_as(user)
    workspace.update!(
      okm_chat_enabled: true,
      okm_drive_id: "drive123",
      okm_service_account_key: okm_service_account_key
    )
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:okm_chat).and_return(true)
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
    allow(Ai::ContextualAgent).to receive(:new) do |**kwargs|
      kwargs[:on_status]&.call("Preparando contexto…")
      chat_agent
    end
    allow(AgentMemoryConsolidationJob).to receive(:perform_later)
  end

  it "streams status updates, reply, session and confirm_action events" do
    pending = Ai::Agent::PendingAction.new(
      tool: "create_task",
      args: {"title" => "Llamar"},
      description: "Crear tarea «Llamar»",
      workspace_id: workspace.id,
      user_id: user.id
    )
    allow(chat_agent).to receive(:call).and_return(
      Ai::ContextualAgent::Result.new(
        reply: "Propongo crear la tarea.",
        pending_actions: [pending],
        session_id: "sess-test"
      )
    )

    post okm_chat_path,
      params: {
        message: "Crea una tarea",
        history: [{role: "user", content: "Hola"}],
        record_type: "companies",
        record_id: company.id
      },
      headers: {"Accept" => "application/x-ndjson"},
      as: :json

    expect(response).to have_http_status(:success)
    events = parse_stream(response.body)
    expect(events.map { |event| event["type"] }).to include("status", "reply", "session", "confirm_action")
    expect(events.find { |e| e["type"] == "reply" }["content"]).to eq("Propongo crear la tarea.")
    expect(events.find { |e| e["type"] == "confirm_action" }["description"]).to eq("Crear tarea «Llamar»")
    expect(Ai::ContextualAgent).to have_received(:new).with(
      hash_including(workspace: workspace, user: user, record: company, message: "Crea una tarea")
    )
  end

  it "works without record context" do
    post okm_chat_path,
      params: {message: "Háblame de Example"},
      headers: {"Accept" => "application/x-ndjson"},
      as: :json

    expect(response).to have_http_status(:success)
    expect(Ai::ContextualAgent).to have_received(:new).with(
      hash_including(record: nil, message: "Háblame de Example")
    )
  end

  it "executes a confirmed action with a valid token" do
    action = Ai::Agent::PendingAction.new(
      tool: "add_note",
      args: {"record_type" => "company", "record_id" => company.id, "body" => "Nota confirmada"},
      description: "Añadir nota",
      workspace_id: workspace.id,
      user_id: user.id
    )

    post okm_chat_actions_path, params: {token: action.sign}, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body["success"]).to be(true)
    expect(company.notes.find_by(body: "Nota confirmada")).to be_present
  end

  it "rejects an action token from another user" do
    other_user = users(:two)
    action = Ai::Agent::PendingAction.new(
      tool: "add_note",
      args: {"record_type" => "company", "record_id" => company.id, "body" => "Hack"},
      description: "Añadir nota",
      workspace_id: workspace.id,
      user_id: other_user.id
    )

    post okm_chat_actions_path, params: {token: action.sign}, as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "returns 404 when the feature is disabled globally" do
    allow(CreamFeatures).to receive(:enabled?).with(:okm_chat).and_return(false)

    post okm_chat_path, params: {message: "Hola"}, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 when OKM chat is disabled for the workspace" do
    workspace.update!(okm_chat_enabled: false)

    post okm_chat_path, params: {message: "Hola"}, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for a record outside the current workspace" do
    post okm_chat_path,
      params: {message: "Hola", record_type: "companies", record_id: other_company.id},
      headers: {"Accept" => "application/x-ndjson"},
      as: :json

    expect(response).to have_http_status(:not_found)
  end
end
