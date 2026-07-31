require "rails_helper"

RSpec.describe DealProduct, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:product) { workspace.products.create!(name: "Plan Pro", price: 100) }

  it "copies the unit price from the product on create" do
    line = deal.deal_products.create!(product: product, quantity: 3)

    expect(line.unit_price).to eq(100)
    expect(line.subtotal).to eq(300)
  end

  it "respects an explicitly provided unit price" do
    line = deal.deal_products.create!(product: product, quantity: 2, unit_price: 80)
    expect(line.unit_price).to eq(80)
  end

  it "recomputes the deal value when lines are added or removed" do
    deal.deal_products.create!(product: product, quantity: 2) # 200
    addon = workspace.products.create!(name: "Add-on", price: 50)
    line = deal.deal_products.create!(product: addon, quantity: 1) # 50

    expect(deal.reload.value).to eq(250)

    line.destroy
    expect(deal.reload.value).to eq(200)
  end

  it "validates quantity is positive" do
    line = deal.deal_products.new(product: product, quantity: 0)
    expect(line).not_to be_valid
  end

  describe "edition resolution" do
    it "creates a product edition from a typed name" do
      line = deal.deal_products.create!(product: product, quantity: 1, edition_name: "Madrid 2026")

      expect(line.edition.name).to eq("Madrid 2026")
      expect(line.edition.product).to eq(product)
      expect(line.edition.workspace).to eq(workspace)
    end

    it "reuses an existing edition instead of duplicating it" do
      first = deal.deal_products.create!(product: product, quantity: 1, edition_name: " Madrid 2026 ")
      second = deal.deal_products.create!(product: product, quantity: 1, edition_name: "Madrid 2026")

      expect(second.edition).to eq(first.edition)
      expect(product.editions.count).to eq(1)
    end

    it "creates separate editions with the same name on different products" do
      other_product = workspace.products.create!(name: "Other", price: 50)
      first = deal.deal_products.create!(product: product, quantity: 1, edition_name: "2026")
      second = deal.deal_products.create!(product: other_product, quantity: 1, edition_name: "2026")

      expect(first.edition).not_to eq(second.edition)
      expect(first.edition.name).to eq(second.edition.name)
    end

    it "leaves the edition blank when no name is given" do
      line = deal.deal_products.create!(product: product, quantity: 1)
      expect(line.edition).to be_nil
    end

    it "clears the edition when the name is emptied" do
      line = deal.deal_products.create!(product: product, quantity: 1, edition_name: "Madrid 2026")
      line.update!(edition_name: "")
      expect(line.reload.edition).to be_nil
    end

    it "assigns an edition by id" do
      edition = product.editions.create!(name: "Madrid 2026")
      line = deal.deal_products.create!(product: product, quantity: 1, edition_id: edition.id)

      expect(line.edition).to eq(edition)
    end

    it "rejects an edition from a different product" do
      other_product = workspace.products.create!(name: "Other", price: 50)
      edition = other_product.editions.create!(name: "Madrid 2026")
      line = deal.deal_products.new(product: product, quantity: 1, edition: edition)

      expect(line).not_to be_valid
      expect(line.errors[:edition]).to be_present
    end

    it "clears the edition when edition_id is blank" do
      edition = product.editions.create!(name: "Madrid 2026")
      line = deal.deal_products.create!(product: product, quantity: 1, edition_id: edition.id)
      line.update!(edition_id: nil)

      expect(line.reload.edition).to be_nil
    end
  end
end
