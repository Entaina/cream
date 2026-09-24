require "rails_helper"

RSpec.describe Marketing::ProductInterest, type: :model do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }
  let(:product) { workspace.products.create!(name: "Course") }

  let(:interest) do
    described_class.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Interested",
      source_kind: "manual",
      occurred_at: Time.current
    )
  end

  it "dismisses with a reason" do
    interest.dismiss!(reason: "Not qualified", actor: users(:one))

    expect(interest.reload.status).to eq("dismissed")
    expect(interest.dismissal_reason).to eq("Not qualified")
  end
end
