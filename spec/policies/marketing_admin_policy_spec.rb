require "rails_helper"

RSpec.describe MarketingAdminPolicy do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:outsider) { users(:outsider) }

  def context_for(user, ws = workspace)
    UserContext.new(user: user, workspace: ws)
  end

  shared_examples "marketing admin only" do |factory|
    let(:record) { send(factory) }

    it "permits admins" do
      policy = described_class.new(context_for(admin), record)
      expect(policy.index?).to be true
      expect(policy.show?).to be true
      expect(policy.create?).to be true
      expect(policy.update?).to be true
      expect(policy.destroy?).to be true
    end

    it "forbids non-admin members" do
      policy = described_class.new(context_for(salesperson), record)
      expect(policy.index?).to be false
      expect(policy.show?).to be false
      expect(policy.create?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
    end
  end

  describe SegmentPolicy do
    let(:segment) { workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {}) }

    include_examples "marketing admin only", :segment
  end

  describe "Scope" do
    let!(:segment) { workspace.segments.create!(name: "S1", record_type: "Person", user: admin, filters: {}) }

    it "returns workspace records for admin" do
      scope = SegmentPolicy::Scope.new(context_for(admin), Segment.all).resolve
      expect(scope).to contain_exactly(segment)
    end

    it "returns nothing for salesperson" do
      scope = SegmentPolicy::Scope.new(context_for(salesperson), Segment.all).resolve
      expect(scope).to be_empty
    end

    it "returns nothing for outsider" do
      scope = SegmentPolicy::Scope.new(context_for(outsider), Segment.all).resolve
      expect(scope).to be_empty
    end
  end
end
