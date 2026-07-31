require "rails_helper"

RSpec.describe "Exports", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  it "exports people as CSV" do
    sign_in_as(member)
    create_person!(workspace)

    get export_path(record_type: "Person")

    expect(response).to have_http_status(:success)
    expect(response.content_type).to include("text/csv")
    expect(response.body).to include("first_name")
  end

  it "exports deals filtered by product and first contact range" do
    sign_in_as(member)
    pipeline = Pipeline.create_default!(workspace)
    company = create_company!(workspace)
    product = workspace.products.create!(name: "Premium", price: 100)
    edition = product.editions.create!(name: "2026")
    contact = create_person!(workspace, company: company, first_contact_on: Date.new(2026, 1, 10))
    match = create_deal!(workspace, pipeline: pipeline, name: "Export match", company: company, contacts: [ contact ])
    match.deal_products.create!(product: product, edition: edition, quantity: 1)
    create_deal!(workspace, pipeline: pipeline, name: "Export other", company: company)

    get export_path(record_type: "Deal", product_id: product.id, edition_id: edition.id,
      first_contact_from: "2026-01-01", first_contact_to: "2026-01-31")

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Export match")
    expect(response.body).not_to include("Export other")
  end
end
