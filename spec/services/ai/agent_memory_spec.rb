require "rails_helper"

RSpec.describe Ai::AgentMemory do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:llmemory) do
    instance_double(
      Llmemory::Memory,
      retrieve: "Memoria relevante",
      add_message: true
    )
  end
  let(:long_term) { instance_double(Llmemory::LongTerm::FileBased::Memory, remember_fact: "fact-1") }

  before do
    allow(Llmemory::Memory).to receive(:new).and_return(llmemory)
    allow(llmemory).to receive(:instance_variable_get).with(:@long_term).and_return(long_term)
    allow(AgentMemoryConsolidationJob).to receive(:perform_later)
  end

  it "builds a scoped user id for llmemory" do
    described_class.new(workspace: workspace, user: user, session_id: "sess-abc")

    expect(Llmemory::Memory).to have_received(:new).with(
      user_id: "ws_#{workspace.id}:user_#{user.id}",
      session_id: "sess-abc"
    )
  end

  it "supports a team-wide sales director memory scope" do
    described_class.new(
      workspace: workspace,
      user: user,
      session_id: "briefing:2026-07-09",
      memory_scope: described_class::TEAM_SCOPE
    )

    expect(Llmemory::Memory).to have_received(:new).with(
      user_id: "ws_#{workspace.id}:sales_director_team",
      session_id: "briefing:2026-07-09"
    )
  end

  it "retrieves context for a query" do
    memory = described_class.new(workspace: workspace, user: user, session_id: "sess-abc")

    expect(memory.context_for("preferencias")).to eq("Memoria relevante")
  end

  it "enqueues consolidation after a turn" do
    memory = described_class.new(workspace: workspace, user: user, session_id: "sess-abc")
    memory.consolidate_later

    expect(AgentMemoryConsolidationJob).to have_received(:perform_later).with(
      "ws_#{workspace.id}:user_#{user.id}",
      "sess-abc"
    )
  end
end
