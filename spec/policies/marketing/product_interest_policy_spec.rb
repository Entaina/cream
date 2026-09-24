require "rails_helper"

RSpec.describe Marketing::ProductInterestPolicy do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }
  let(:outsider) { users(:outsider) }
  let(:person) { create_person!(workspace, company: companies(:acme)) }
  let(:product) { workspace.products.create!(name: "Pro") }

  def context_for(user)
    UserContext.new(user: user, workspace: workspace)
  end

  let(:interest) do
    Marketing::ProductInterest.create!(
      workspace: workspace,
      person: person,
      product: product,
      description: "Interested",
      source_kind: "manual",
      occurred_at: Time.current
    )
  end

  it "allows members to create, dismiss, and convert when they can update the person" do
    policy = described_class.new(context_for(member), interest)
    expect(policy.create?).to be true
    expect(policy.dismiss?).to be true
    expect(policy.convert?).to be true
  end

  it "forbids outsiders" do
    policy = described_class.new(context_for(outsider), interest)
    expect(policy.create?).to be false
    expect(policy.dismiss?).to be false
    expect(policy.convert?).to be false
  end
end
