require "rails_helper"

RSpec.describe "AI salesperson role", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:ai_user) { users(:outsider) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let!(:own_deal) { create_deal!(workspace, pipeline: pipeline, owner: ai_user, name: "Own deal") }
  let!(:other_deal) { create_deal!(workspace, pipeline: pipeline, owner: admin, name: "Other deal") }

  before do
    Membership.create!(user: ai_user, workspace: workspace, role: "ai_salesperson")
    sign_in_as(ai_user)
  end

  it "is a valid membership role" do
    expect(Membership::ROLES).to include("ai_salesperson")
    expect(Membership.role_label_for("ai_salesperson")).to eq(I18n.t("integrations.team.roles.ai_salesperson"))
  end

  it "lists only their own deals" do
    get deals_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Own deal")
    expect(response.body).not_to include("Other deal")
  end

  it "cannot open deals owned by others" do
    get deal_path(other_deal)

    expect(response).to have_http_status(:not_found)
  end

  it "can update their own deals" do
    patch deal_path(own_deal), params: {deal: {name: "Renamed"}}

    expect(own_deal.reload.name).to eq("Renamed")
  end

  it "cannot delete their own deals" do
    expect { delete deal_path(own_deal) }.not_to change(Deal, :count)

    expect(response).to redirect_to(root_path)
  end

  it "cannot delete other records" do
    company = companies(:acme)

    expect { delete company_path(company) }.not_to change(Company, :count)
  end

  it "cannot delete records authorized through the parent deal (offers)" do
    offer = own_deal.offers.create!(workspace: workspace, user: ai_user, name: "Oferta")
    offer.versions.create!(user: ai_user, html_body: "<p>x</p>")

    expect { delete deal_offer_path(own_deal, offer) }.not_to change(own_deal.offers, :count)
  end

  it "cannot delete offer versions" do
    offer = own_deal.offers.create!(workspace: workspace, user: ai_user, name: "Oferta")
    offer.versions.create!(user: ai_user, html_body: "<p>1</p>")
    version = offer.versions.create!(user: ai_user, html_body: "<p>2</p>")

    expect { delete deal_offer_version_path(own_deal, offer, version) }.not_to change(OfferVersion, :count)
  end

  it "cannot delete product lines of their deals" do
    product = Product.create!(workspace: workspace, name: "Curso", price: 10)
    line = own_deal.deal_products.create!(product: product, quantity: 1, unit_price: 10)

    expect { delete deal_line_item_path(own_deal, line) }.not_to change(DealProduct, :count)
  end

  it "cannot remove product lines through nested attributes" do
    product = Product.create!(workspace: workspace, name: "Curso", price: 10)
    line = own_deal.deal_products.create!(product: product, quantity: 1, unit_price: 10)

    expect {
      patch deal_path(own_deal), params: {deal: {deal_products_attributes: {"0" => {id: line.id, _destroy: "1"}}}}
    }.not_to change(DealProduct, :count)
  end

  it "cannot unlink contacts from a deal, but can add them" do
    existing = create_person!(workspace, company: own_deal.company, first_name: "Existente")
    added = create_person!(workspace, company: own_deal.company, first_name: "Nuevo")
    own_deal.update!(contact_ids: [existing.id])

    patch deal_path(own_deal), params: {deal: {contact_ids: ["", added.id.to_s]}}
    expect(own_deal.reload.contacts).to eq([existing])

    patch deal_path(own_deal), params: {deal: {contact_ids: ["", existing.id.to_s, added.id.to_s]}}
    expect(own_deal.reload.contacts).to contain_exactly(existing, added)
  end

  it "cannot remove collaborators" do
    own_deal.deal_accesses.create!(user: admin)

    expect {
      delete deal_deal_access_path(own_deal, own_deal.deal_accesses.first)
    }.not_to change(DealAccess, :count)
  end

  it "can still log out" do
    expect { delete session_path }.to change(Session, :count).by(-1)

    expect(response).to redirect_to(new_session_path)
  end
end
