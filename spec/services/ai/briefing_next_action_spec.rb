require "rails_helper"

RSpec.describe Ai::BriefingNextAction do
  describe ".filter_items" do
    let(:open_deals) do
      [
        {
          id: 10,
          has_scheduled_next_action: true,
          next_action: {id: 501, title: "Llamada", due_on: "2026-08-17", status: "scheduled"}
        }
      ]
    end

    it "drops parallel action items for deals with a scheduled next action" do
      items = [
        {"priority" => "urgent", "text" => "Reactivar Delta Furniture hoy", "record_type" => "Deal", "record_id" => 10},
        {"priority" => "important", "text" => "Revisar forecast", "record_type" => nil, "record_id" => nil}
      ]

      filtered = described_class.filter_items(items, open_deals)

      expect(filtered.size).to eq(1)
      expect(filtered.first["text"]).to include("forecast")
    end

    it "keeps reschedule suggestions for protected deals" do
      items = [
        {"priority" => "important", "text" => "Adelantar la llamada con Delta Furniture", "record_type" => "Deal", "record_id" => 10}
      ]

      filtered = described_class.filter_items(items, open_deals)

      expect(filtered).to eq(items)
    end

    it "drops task items tied to the scheduled next action" do
      items = [
        {"priority" => "urgent", "text" => "Hacer seguimiento hoy", "record_type" => "Task", "record_id" => 501}
      ]

      filtered = described_class.filter_items(items, open_deals)

      expect(filtered).to be_empty
    end
  end
end
