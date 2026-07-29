require "rails_helper"

RSpec.describe "Deal product lines", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:product) { workspace.products.create!(name: "Plan Pro", price: 100) }

  it "adds a product line and recomputes the deal value" do
    sign_in_as(member)

    post deal_line_items_path(deal), params: { deal_product: { product_id: product.id, quantity: 3 } }

    expect(response).to redirect_to(deal_path(deal))
    expect(deal.reload.value).to eq(300)
  end

  it "adds a product line with an edition by id" do
    sign_in_as(member)
    edition = workspace.editions.create!(name: "Madrid 2026")

    post deal_line_items_path(deal), params: {
      deal_product: { product_id: product.id, quantity: 1, edition_id: edition.id }
    }

    line = deal.deal_products.last
    expect(line.edition).to eq(edition)
    expect(response).to redirect_to(deal_path(deal))
  end

  it "updates the edition on a line by id" do
    sign_in_as(member)
    edition = workspace.editions.create!(name: "Madrid 2026")
    line = deal.deal_products.create!(product: product, quantity: 1)

    patch deal_line_item_path(deal, line), params: { deal_product: { edition_id: edition.id } }

    expect(line.reload.edition).to eq(edition)
    expect(response).to redirect_to(deal_path(deal))
  end

  it "removes a line and recomputes the value" do
    sign_in_as(member)
    line = deal.deal_products.create!(product: product, quantity: 2)

    delete deal_line_item_path(deal, line)

    expect(deal.reload.value).to eq(0)
  end
end
