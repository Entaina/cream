require "rails_helper"

RSpec.describe Edition, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:product) { workspace.products.create!(name: "Course", price: 100) }

  it "requires a name unique per product (case-insensitive)" do
    product.editions.create!(name: "Madrid 2026")
    duplicate = product.editions.new(name: " madrid 2026 ")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "allows the same name on different products in the same workspace" do
    product.editions.create!(name: "Madrid 2026")
    other_product = workspace.products.create!(name: "Other course", price: 50)
    expect(other_product.editions.create!(name: "Madrid 2026")).to be_persisted
  end

  it "sets workspace from the product on create" do
    edition = product.editions.create!(name: "Spring")
    expect(edition.workspace).to eq(workspace)
  end

  describe "date range validation" do
    it "accepts blank dates" do
      edition = product.editions.new(name: "Open")
      expect(edition).to be_valid
    end

    it "accepts only a start date" do
      edition = product.editions.new(name: "Spring", starts_on: Date.new(2026, 3, 1))
      expect(edition).to be_valid
    end

    it "accepts only an end date" do
      edition = product.editions.new(name: "Spring", ends_on: Date.new(2026, 6, 30))
      expect(edition).to be_valid
    end

    it "rejects an end date before the start date" do
      edition = product.editions.new(
        name: "Invalid",
        starts_on: Date.new(2026, 6, 1),
        ends_on: Date.new(2026, 5, 1)
      )
      expect(edition).not_to be_valid
      expect(edition.errors[:ends_on]).to be_present
    end
  end

  describe "#date_range_label" do
    it "returns nil when there are no dates" do
      edition = product.editions.new(name: "No dates")
      expect(edition.date_range_label).to be_nil
    end

    it "formats a full range" do
      edition = product.editions.new(
        name: "Cohort",
        starts_on: Date.new(2026, 1, 12),
        ends_on: Date.new(2026, 3, 20)
      )
      expect(edition.date_range_label).to include("Jan 12")
      expect(edition.date_range_label).to include("Mar 20")
    end

    it "formats a start-only range" do
      edition = product.editions.new(name: "Cohort", starts_on: Date.new(2026, 1, 12))
      expect(edition.date_range_label).to start_with("From ")
    end

    it "formats an end-only range" do
      edition = product.editions.new(name: "Cohort", ends_on: Date.new(2026, 3, 20))
      expect(edition.date_range_label).to start_with("Until ")
    end
  end
end
