require "rails_helper"

RSpec.describe LeadFormTemplates::FieldRenderer do
  describe ".parse_choice_pairs" do
    it "parses label|value pairs separated by semicolons" do
      pairs = described_class.parse_choice_pairs("Curso|curso; Entrenamiento|entrenamiento")

      expect(pairs).to eq([ [ "Curso", "curso" ], [ "Entrenamiento", "entrenamiento" ] ])
    end

    it "uses the same string for label and value when no pipe is present" do
      pairs = described_class.parse_choice_pairs("+34; +351")

      expect(pairs).to eq([ [ "+34", "+34" ], [ "+351", "+351" ] ])
    end

    it "returns an empty array for blank input" do
      expect(described_class.parse_choice_pairs(nil)).to eq([])
      expect(described_class.parse_choice_pairs("")).to eq([])
    end
  end
end
