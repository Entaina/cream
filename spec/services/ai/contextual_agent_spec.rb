require "rails_helper"

RSpec.describe Ai::ContextualAgent do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { companies(:acme) }
  let(:person) { create_person!(workspace, company: company, first_name: "Alex", last_name: "Rios") }
  let(:client) { instance_double(Ai::Client) }
  let(:drive) { instance_double(Okm::DriveClient) }
  let(:memory) do
    instance_double(
      Ai::AgentMemory,
      session_id: "sess-1",
      context_for: "",
      record_turn: true,
      consolidate_later: true,
      remember_fact: "fact-id"
    )
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
    workspace.update!(okm_drive_id: "drive123", okm_service_account_key: okm_service_account_key)
    allow(client).to receive(:chat_with_tools).and_return("Respuesta del asistente")
    allow(drive).to receive(:search).and_return([])
    allow(drive).to receive(:read_file).and_return("")
    allow(AgentMemoryConsolidationJob).to receive(:perform_later)
  end

  def build_agent(**kwargs)
    described_class.new(
      workspace: workspace,
      user: user,
      client: client,
      drive: drive,
      memory: memory,
      **kwargs
    )
  end

  it "calls the LLM with CRM context and the full tool catalogue" do
    build_agent(record: company, message: "¿Qué sabemos de este cliente?").call

    expect(client).to have_received(:chat_with_tools) do |**args|
      expect(args[:system]).to include("commercial assistant")
      expect(args[:input]).to include("Acme Corp")
      expect(args[:input]).to include("¿Qué sabemos de este cliente?")
      tool_names = args[:tools].map { |tool| tool[:name] }
      expect(tool_names).to include(
        "search_okm", "search_records", "create_task", "list_people", "send_campaign", "remember", "recall"
      )
      expect(tool_names).not_to include("update_record")
      expect(args[:max_iterations]).to eq(12)
    end
  end

  it "includes related company context for a person record" do
    build_agent(record: person, message: "Resume el contexto").call

    expect(client).to have_received(:chat_with_tools) do |**args|
      expect(args[:input]).to include("Alex")
      expect(args[:input]).to include("related_company")
      expect(args[:input]).to include("Acme Corp")
    end
  end

  it "works without a CRM record" do
    build_agent(record: nil, message: "¿Cuál es el posicionamiento de Example?").call

    expect(client).to have_received(:chat_with_tools) do |**args|
      expect(args[:input]).not_to include("CRM context")
      expect(args[:input]).to include("posicionamiento")
    end
  end

  it "returns a Result with reply and pending actions" do
    allow(client).to receive(:chat_with_tools).and_yield("create_task", {"title" => "Llamar"}).and_return("Propongo crear tarea")

    result = build_agent(record: company, message: "Crea una tarea").call

    expect(result).to be_a(described_class::Result)
    expect(result.reply).to eq("Propongo crear tarea")
    expect(result.session_id).to eq("sess-1")
    expect(result.pending_actions.size).to eq(1)
    expect(result.pending_actions.first.tool).to eq("create_task")
  end

  it "records the turn and enqueues memory consolidation" do
    build_agent(record: company, message: "Hola").call

    expect(memory).to have_received(:record_turn).with(
      user_message: "Hola",
      assistant_message: "Respuesta del asistente"
    )
    expect(memory).to have_received(:consolidate_later)
  end

  it "notifies status during prefetch and tool calls" do
    result = Okm::DriveClient::SearchResult.new(
      id: "f1", name: "Contexto de Cliente.md", mime_type: "text/markdown", parent_id: "p1"
    )
    allow(drive).to receive(:search).with("Acme Corp").and_return([result])
    allow(drive).to receive(:read_file).with("f1").and_return("Contexto del cliente Acme")
    statuses = []
    allow(client).to receive(:chat_with_tools).and_yield("search_okm", {"query" => "ventas"}).and_return("ok")

    build_agent(
      record: company,
      message: "¿Qué sabemos?",
      on_status: ->(message) { statuses << message }
    ).call

    expect(statuses).to include(
      "Preparando contexto…",
      "Buscando en el OKM: Acme Corp…",
      "Leyendo Contexto de Cliente.md…",
      "Consultando con IA…",
      "Buscando en el OKM: ventas…"
    )
  end

  it "returns a friendly message when the tool loop is exceeded" do
    allow(client).to receive(:chat_with_tools).and_raise(Ai::Client::Error, "Tool loop exceeded 12 iterations")

    result = build_agent(record: company, message: "Explora todo el OKM").call

    expect(result.reply).to include("demasiadas búsquedas")
    expect(result.pending_actions).to be_empty
  end

  it "raises when the message is blank" do
    expect {
      build_agent(record: company, message: "  ").call
    }.to raise_error(Ai::Client::Error, /blank/)
  end
end
