require "rails_helper"

RSpec.describe UserContext do
  fixtures :users, :workspaces, :memberships

  let(:superadmin) { users(:superadmin) }
  let(:workspace) { workspaces(:one) }

  it "treats superadmin as member and admin without membership" do
    context = described_class.new(user: superadmin, workspace: workspace)

    expect(context.member?).to be(true)
    expect(context.admin?).to be(true)
    expect(context.membership).to be_nil
  end
end
