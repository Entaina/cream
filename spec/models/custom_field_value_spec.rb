require "rails_helper"

RSpec.describe CustomFieldValue do
  fixtures :workspaces, :companies, :custom_fields, :custom_field_values

  let(:value) { custom_field_values(:company_segment_acme) }

  describe "#typed_value" do
    it "returns stored text values" do
      expect(value.typed_value).to eq("Enterprise")
    end
  end

  describe "#blank_value?" do
    it "detects empty values" do
      expect(value.blank_value?).to be false

      empty = described_class.new(value: nil)
      expect(empty.blank_value?).to be true
    end
  end
end
