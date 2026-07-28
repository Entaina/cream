require "rails_helper"

RSpec.describe Membership, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  describe "role helpers" do
    it "identifies admin, sales director and salesperson roles" do
      admin_membership = memberships(:one_one)
      salesperson_membership = memberships(:one_member)
      director_membership = memberships(:one_sales_director)

      expect(admin_membership.admin?).to be true
      expect(admin_membership.sales_director?).to be false
      expect(admin_membership.salesperson?).to be false
      expect(admin_membership.role_label).to eq("Admin")

      expect(salesperson_membership.admin?).to be false
      expect(salesperson_membership.salesperson?).to be true
      expect(salesperson_membership.role_label).to eq("Vendedor")

      expect(director_membership.sales_director?).to be true
      expect(director_membership.role_label).to eq("Director comercial")
    end
  end

  describe "current pipeline" do
    it "defaults to the workspace default pipeline on create" do
      pipeline = Pipeline.default_for(workspace)
      membership = Membership.create!(user: users(:outsider), workspace: workspace, role: "salesperson")

      expect(membership.current_pipeline).to eq(pipeline)
    end

    it "allows a nil current pipeline" do
      membership = memberships(:one_one)
      membership.current_pipeline = nil

      expect(membership).to be_valid
    end

    it "rejects a pipeline from another workspace" do
      other_workspace = workspaces(:two)
      other_pipeline = Pipeline.create_default!(other_workspace)
      membership = memberships(:one_one)
      membership.current_pipeline = other_pipeline

      expect(membership).not_to be_valid
      expect(membership.errors[:current_pipeline]).to include("must belong to the workspace")
    end
  end

  describe "sales director briefing regenerations" do
    let(:membership) { memberships(:one_one) }

    it "allows up to 5 regenerations per day" do
      Membership::SALES_BRIEFING_DAILY_REGENERATIONS_LIMIT.times do
        expect(membership.can_regenerate_sales_briefing?).to be(true)
        membership.record_sales_briefing_regeneration!
      end

      expect(membership.can_regenerate_sales_briefing?).to be(false)
      expect(membership.sales_briefing_regenerations_remaining).to eq(0)
    end

    it "resets the counter on a new day" do
      membership.update!(
        sales_briefing_regenerations_count: 5,
        sales_briefing_regenerations_on: Date.current - 1.day
      )

      expect(membership.sales_briefing_regenerations_today).to eq(0)
      expect(membership.can_regenerate_sales_briefing?).to be(true)
      expect(membership.sales_briefing_regenerations_remaining).to eq(5)
    end
  end

  describe "sales director briefing visibility" do
    before do
      workspace.update!(sales_director_enabled: true)
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:sales_director).and_return(true)
      allow(Ai::Configuration).to receive(:configured?).and_return(true)
    end

    it "is visible when all flags are enabled" do
      membership = memberships(:one_one)

      expect(membership.sales_director_briefing_visible?).to be(true)
    end

    it "is hidden when the user disabled the preference" do
      membership = memberships(:one_one)
      membership.update!(sales_director_briefing_enabled: false)

      expect(membership.sales_director_briefing_visible?).to be(false)
    end

    it "is hidden when the workspace disabled sales director" do
      workspace.update!(sales_director_enabled: false)
      membership = memberships(:one_one)

      expect(membership.sales_director_briefing_visible?).to be(false)
    end

    it "is hidden when AI is not configured" do
      allow(Ai::Configuration).to receive(:configured?).and_return(false)
      membership = memberships(:one_one)

      expect(membership.sales_director_briefing_visible?).to be(false)
    end
  end

  describe "last admin protection" do
    it "prevents demoting the last admin" do
      membership = memberships(:one_one)

      expect(membership.update(role: "salesperson")).to be false
      expect(membership.errors[:role]).to include("cannot demote the last admin")
    end

    it "prevents removing the last admin" do
      membership = memberships(:one_one)

      expect(membership.destroy).to be false
      expect(membership.errors[:base]).to include("Cannot remove the last admin from the workspace")
    end
  end
end
