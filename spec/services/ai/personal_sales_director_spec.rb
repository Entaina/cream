require "rails_helper"

RSpec.describe Ai::PersonalSalesDirector do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:client) { instance_double(Ai::Client) }

  before do
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
    allow(Ai::SalesDirectorResearch).to receive(:new).and_return(
      instance_double(Ai::SalesDirectorResearch, call: "Contexto OKM relevante")
    )
    memory = instance_double(Ai::AgentMemory, record_turn: true, consolidate_later: true)
    allow(Ai::AgentMemory).to receive(:new).and_return(memory)
    allow(AgentMemoryConsolidationJob).to receive(:perform_later)
  end

  it "creates a personal briefing from normalized LLM output" do
    allow(client).to receive(:chat).and_return({
      summary: "Hoy debes priorizar tus deals en negociación",
      items: [
        {
          priority: "urgent",
          text: "Llama hoy a ACME para cerrar el deal",
          record_type: "Deal",
          record_id: 42
        }
      ],
      wins: [ "Cerraste el deal Beta a tiempo" ],
      misses: [ "Dejaste vencer la tarea de seguimiento con Gamma; reprograma hoy" ]
    }.to_json)

    briefing = described_class.new(workspace: workspace, user: user, client: client).call

    expect(briefing).to be_persisted
    expect(briefing.user).to eq(user)
    expect(briefing.summary).to include("priorizar")
    expect(briefing.urgent_items.first["text"]).to include("ACME")
    expect(briefing.wins).to eq([ "Cerraste el deal Beta a tiempo" ])
    expect(briefing.misses.first).to include("Gamma")
    expect(client).to have_received(:chat) do |**args|
      expect(args[:user]).to include("Investigación OKM, CRM y memoria")
      expect(args[:user]).to include("Contexto OKM relevante")
    end
  end

  it "upserts the personal briefing for the same day" do
    workspace.sales_briefings.create!(
      user: user,
      briefing_date: Date.current,
      summary: "Antiguo",
      items: [],
      wins: [],
      misses: [],
      generated_at: 1.hour.ago
    )

    allow(client).to receive(:chat).and_return({
      summary: "Nuevo resumen personal",
      items: [ { priority: "important", text: "Prepara propuesta" } ],
      wins: [ "Buen avance" ],
      misses: []
    }.to_json)

    briefing = described_class.new(workspace: workspace, user: user, client: client).call

    expect(workspace.sales_briefings.personal.count).to eq(1)
    expect(briefing.summary).to eq("Nuevo resumen personal")
  end

  it "returns nil when AI is not configured" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    expect(client).not_to receive(:chat)
    expect(described_class.new(workspace: workspace, user: user, client: client).call).to be_nil
  end

  describe "next-action aware briefing" do
    let(:briefing_date) { Date.current }
    let!(:deal) do
      create_deal!(
        workspace,
        name: "Delta Furniture",
        owner: user,
        tasks: [
          Task.new(
            title: "Llamada comercial",
            due_on: briefing_date + 21.days,
            workspace: workspace,
            user: user,
            assignee: user
          )
        ]
      )
    end

    it "filters parallel recommendations for deals with a scheduled next action" do
      allow(client).to receive(:chat).and_return({
        summary: "Tu pipeline está bien",
        items: [
          {
            priority: "urgent",
            text: "Reactiva Delta Furniture hoy",
            record_type: "Deal",
            record_id: deal.id
          },
          {
            priority: "important",
            text: "Adelantar la llamada con Delta Furniture",
            record_type: "Deal",
            record_id: deal.id
          }
        ],
        wins: [],
        misses: []
      }.to_json)

      briefing = described_class.new(workspace: workspace, user: user, briefing_date: briefing_date, client: client).call

      expect(briefing.urgent_items).to be_empty
      expect(briefing.important_items.first["text"]).to include("Adelantar")
    end
  end
end
