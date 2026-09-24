require "rails_helper"

RSpec.describe "People::ProductInterests", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:member) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }
  let(:product) { workspace.products.create!(name: "Course") }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    sign_in_as(member)
    patch switch_workspace_path, params: {workspace_id: workspace.id}
  end

  it "registers product interest on a person" do
    expect {
      post person_product_interests_path(person), params: {
        product_interest: {product_id: product.id, description: "Asked for demo"}
      }
    }.to change(Marketing::ProductInterest, :count).by(1)

    expect(response).to redirect_to(person_path(person))
    expect(Marketing::ProductInterest.last).to be_pending
  end

  it "dismisses a pending interest" do
    interest = Marketing::ProductInterest.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Old",
      source_kind: "manual",
      occurred_at: Time.current
    )

    patch dismiss_person_product_interest_path(person, interest), params: {dismissal_reason: "Not a fit"}

    expect(response).to redirect_to(person_path(person))
    expect(interest.reload.status).to eq("dismissed")
  end
end
