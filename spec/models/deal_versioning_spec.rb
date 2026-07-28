require "rails_helper"

RSpec.describe "Deal versioning", type: :model do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }
  let(:product) { workspace.products.create!(name: "Plan Pro", price: 100) }

  before do
    Current.session = user.sessions.create!
    Current.workspace = workspace
    PaperTrail.request.whodunnit = user.id.to_s
  end

  after do
    PaperTrail.request.whodunnit = nil
  end

  it "creates a version when the deal is created" do
    expect(deal.versions.count).to eq(1)
    expect(deal.versions.last.event).to eq("create")
    expect(deal.versions.last.workspace_id).to eq(workspace.id)
    expect(deal.versions.last.whodunnit).to eq(user.id.to_s)
  end

  it "records value changes in versions" do
    deal.update!(value: 5000)

    version = deal.versions.last
    expect(version.event).to eq("update")
    expect(version.changeset).to have_key("value")
    expect(version.changeset["value"].last.to_f).to eq(5000.0)
  end

  it "records name and probability changes with whodunnit" do
    deal.update!(name: "Renamed deal", probability: 40)

    version = deal.versions.last
    expect(version.changeset.keys).to include("name", "probability")
    expect(version.whodunnit).to eq(user.id.to_s)
  end

  it "reifies the previous deal state" do
    original_name = deal.name
    deal.update!(name: "Changed name")

    expect(deal.paper_trail.previous_version.name).to eq(original_name)
  end

  it "logs contacts_changed when a contact is added" do
    company = deal.company
    contact = create_person!(workspace, company: company, first_name: "Extra", last_name: "Contact")

    expect {
      deal.deal_contacts.create!(person: contact)
    }.to change { deal.activities.where(action: "contacts_changed").count }.by(1)

    activity = deal.activities.where(action: "contacts_changed").last
    expect(activity.metadata["change"]).to eq("added")
    expect(activity.metadata["contact"]).to include("Extra")
  end

  it "logs products_changed when a product line is added" do
    expect {
      deal.deal_products.create!(product: product, quantity: 2)
    }.to change { deal.activities.where(action: "products_changed").count }.by(1)

    activity = deal.activities.where(action: "products_changed").last
    expect(activity.metadata["change"]).to eq("added")
    expect(activity.metadata["product"]).to eq("Plan Pro")
  end
end
