require "rails_helper"

RSpec.describe CustomField do
  fixtures :workspaces, :custom_fields

  let(:workspace) { workspaces(:one) }

  describe "validations" do
    it "derives a unique key from the name" do
      field = workspaces(:two).custom_fields.create!(record_type: "Person", name: "Customer Tier", field_type: "text")

      expect(field.key).to eq("customer_tier")
    end

    it "requires options for select fields" do
      field = workspace.custom_fields.new(record_type: "Person", name: "Status", field_type: "select", options: [])

      expect(field).not_to be_valid
      expect(field.errors[:options]).to be_present
    end

    it "requires reference_type for record reference fields" do
      field = workspace.custom_fields.new(record_type: "Person", name: "Partner", field_type: "record_reference")

      expect(field).not_to be_valid
      expect(field.errors[:reference_type]).to be_present
    end
  end

  describe "#cast" do
    it "casts values by field type" do
      field = described_class.new(field_type: "boolean")
      expect(field.cast("1")).to be true
      expect(field.cast("0")).to be false

      number = described_class.new(field_type: "number")
      expect(number.cast("42")).to eq(BigDecimal(42))

      multi = described_class.new(field_type: "multi_select")
      expect(multi.cast([" A ", "", "B"])).to eq(%w[A B])

      reference = described_class.new(field_type: "record_reference")
      expect(reference.cast("42")).to eq(42)
      expect(reference.cast("")).to be_nil
      expect(reference.cast("abc")).to be_nil
    end
  end

  describe "#reference_scope" do
    it "returns workspace companies for a company reference field" do
      field = custom_fields(:person_related_company)

      expect(field.reference_scope(workspace).to_sql).to include("companies")
    end
  end
end
