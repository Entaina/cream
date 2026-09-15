require "rails_helper"

RSpec.describe Ai::SalesDirectorResearch do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:client) { instance_double(Ai::Client) }
  let(:memory) do
    instance_double(
      Ai::AgentMemory,
      context_for: "Memoria previa del equipo",
      session_id: "briefing:2026-07-09"
    )
  end
  let(:registry) { instance_double(Ai::Agent::ToolRegistry, definitions: [{name: "search_records"}]) }
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
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
    allow(Ai::Agent::ToolRegistry).to receive(:new).and_return(registry)
    allow(registry).to receive(:execute).and_return("resultado")
    allow(registry).to receive(:prefetch_okm).and_return("Contexto OKM")
    allow(client).to receive(:chat_with_tools).and_return("Resumen de investigación")
  end

  it "uses read-only tools and returns research notes" do
    notes = described_class.new(
      workspace: workspace,
      user: user,
      briefing_date: Date.new(2026, 7, 9),
      prefetch_terms: ["Acme Corp"],
      memory_scope: Ai::AgentMemory::TEAM_SCOPE,
      client: client,
      memory: memory
    ).call

    expect(notes).to eq("Resumen de investigación")
    expect(Ai::Agent::ToolRegistry).to have_received(:new).with(
      hash_including(workspace: workspace, user: user, write: false, okm: true, memory: memory)
    )
    expect(client).to have_received(:chat_with_tools) do |**args|
      expect(args[:input]).to include("Memoria previa del equipo")
      expect(args[:input]).to include("Contexto OKM")
    end
  end

  it "returns an empty string when AI is not configured" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    notes = described_class.new(workspace: workspace, user: user, briefing_date: Date.current, client: client).call

    expect(notes).to eq("")
    expect(client).not_to have_received(:chat_with_tools)
  end
end
