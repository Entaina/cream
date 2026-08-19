require "rails_helper"

RSpec.describe Ai::SalesDirector do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:client) { instance_double(Ai::Client) }
  let(:memory) { instance_double(Ai::AgentMemory, record_turn: true, consolidate_later: true) }

  before do
    allow(Ai::Configuration).to receive(:configured?).and_return(true)
    allow(Ai::SalesDirectorResearch).to receive(:new).and_return(
      instance_double(Ai::SalesDirectorResearch, call: "")
    )
    allow(Ai::AgentMemory).to receive(:new).and_return(memory)
    allow(AgentMemoryConsolidationJob).to receive(:perform_later)
  end

  it "creates a briefing from normalized LLM output" do
    allow(client).to receive(:chat).and_return({
      summary: "El pipeline necesita atención",
      items: [
        {
          priority: "urgent",
          text: "Cerrar el deal ACME esta semana",
          record_type: "Deal",
          record_id: 42,
          owner_id: users(:one).id
        },
        {
          priority: "important",
          text: "Revisar propuestas en negociación",
          record_type: nil,
          record_id: nil,
          owner_id: nil
        }
      ]
    }.to_json)

    briefing = described_class.new(workspace: workspace, client: client).call

    expect(briefing).to be_persisted
    expect(briefing.summary).to eq("El pipeline necesita atención")
    expect(briefing.urgent_items.first["text"]).to eq("Cerrar el deal ACME esta semana")
    expect(briefing.important_items.size).to eq(1)
    expect(briefing.briefing_date).to eq(Date.current)
    expect(Ai::SalesDirectorResearch).to have_received(:new)
    expect(memory).to have_received(:consolidate_later)
  end

  it "upserts the briefing for the same day" do
    workspace.sales_briefings.create!(
      briefing_date: Date.current,
      summary: "Antiguo",
      items: [],
      generated_at: 1.hour.ago
    )

    allow(client).to receive(:chat).and_return({
      summary: "Nuevo resumen",
      items: [ { priority: "urgent", text: "Actualizar forecast" } ]
    }.to_json)

    briefing = described_class.new(workspace: workspace, client: client).call

    expect(workspace.sales_briefings.count).to eq(1)
    expect(briefing.summary).to eq("Nuevo resumen")
  end

  it "returns nil when AI is not configured" do
    allow(Ai::Configuration).to receive(:configured?).and_return(false)

    expect(client).not_to receive(:chat)
    expect(described_class.new(workspace: workspace, client: client).call).to be_nil
  end

  describe "next-action aware briefing" do
    let(:briefing_date) { Date.current }
    let(:actor) { users(:one) }
    let!(:deal) do
      create_deal!(
        workspace,
        name: "Delta Furniture",
        owner: actor,
        tasks: [
          Task.new(
            title: "Llamada comercial",
            due_on: briefing_date + 21.days,
            workspace: workspace,
            user: actor,
            assignee: actor
          )
        ]
      )
    end

    it "includes next_action in context and filters parallel recommendations" do
      captured_user = nil
      allow(client).to receive(:chat) do |**args|
        captured_user = args[:user]
        {
          summary: "Pipeline estable",
          items: [
            {
              priority: "urgent",
              text: "Reactivar Delta Furniture hoy; lleva 13 días sin actividad",
              record_type: "Deal",
              record_id: deal.id,
              owner_id: actor.id
            },
            {
              priority: "important",
              text: "Adelantar la llamada con Delta Furniture",
              record_type: "Deal",
              record_id: deal.id,
              owner_id: actor.id
            }
          ]
        }.to_json
      end

      briefing = described_class.new(workspace: workspace, briefing_date: briefing_date, client: client).call

      context = JSON.parse(captured_user[/\n\n(\{.*)\z/m, 1])
      deal_context = context.fetch("open_deals").find { |entry| entry["id"] == deal.id }
      expect(deal_context["has_scheduled_next_action"]).to be(true)
      expect(deal_context["next_action"]["title"]).to eq("Llamada comercial")
      expect(deal_context).not_to have_key("days_since_last_activity")

      expect(briefing.urgent_items).to be_empty
      expect(briefing.important_items.first["text"]).to include("Adelantar")
    end

    it "keeps missing next step recommendations for deals without open tasks" do
      deal.tasks.destroy_all

      allow(client).to receive(:chat).and_return({
        summary: "Hay deals sin siguiente paso",
        items: [
          {
            priority: "urgent",
            text: "Define la próxima acción para Delta Furniture",
            record_type: "Deal",
            record_id: deal.id,
            owner_id: actor.id
          }
        ]
      }.to_json)

      briefing = described_class.new(workspace: workspace, briefing_date: briefing_date, client: client).call

      expect(briefing.urgent_items.first["text"]).to include("próxima acción")
    end
  end
end
