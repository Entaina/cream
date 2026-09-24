require "rails_helper"

RSpec.describe Marketing::ApiPresenter do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:admin) { users(:one) }

  before { SubscriptionType.ensure_defaults!(workspace) }

  describe ".mql_json" do
    it "includes core person marketing fields" do
      person = create_person!(workspace, company: companies(:acme), email: "mql@acme.com", lead_score: 5)

      json = described_class.mql_json(person)

      expect(json).to include(
        id: person.id,
        email: "mql@acme.com",
        lead_score: 5,
        company: companies(:acme).name
      )
      expect(json[:marketing_eligible]).to be_in([true, false])
    end
  end

  describe ".person_ref_json" do
    it "returns type, id, and name" do
      person = create_person!(workspace, company: companies(:acme))
      json = described_class.person_ref_json(person)

      expect(json).to include(type: "person", id: person.id, name: person.display_name)
    end
  end

  describe ".list_limit" do
    it "clamps values to the allowed range" do
      expect(described_class.list_limit(nil)).to eq(25)
      expect(described_class.list_limit(500)).to eq(100)
      expect(described_class.list_limit(10)).to eq(10)
    end
  end
end
