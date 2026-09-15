require "rails_helper"

RSpec.describe ListFilters do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:owner) { users(:one) }

  describe ".apply_owner" do
    it "returns unassigned records when owner_id is none" do
      company = create_company!(workspace)
      unassigned = create_person!(workspace, company: company, first_name: "Solo", owner: nil)
      assigned = create_person!(workspace, company: company, first_name: "Owned", owner: owner)

      result = described_class.apply_owner(workspace.people, described_class::NONE)

      expect(result).to contain_exactly(unassigned)
      expect(result).not_to include(assigned)
    end
  end

  describe ".apply_industry" do
    it "returns companies with blank industry when industry is none" do
      blank = workspace.companies.create!(name: "Blank industry Co", industry: nil)
      tagged = workspace.companies.create!(name: "SaaS Co", industry: "SaaS")

      result = described_class.apply_industry(
        workspace.companies.where(id: [blank.id, tagged.id]),
        described_class::NONE
      )

      expect(result).to contain_exactly(blank)
    end
  end
end
