require "rails_helper"

RSpec.describe PersonRelationship, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:company) { create_company!(workspace) }
  let(:alice) { create_person!(workspace, company: company, first_name: "Alice") }
  let(:bob) { create_person!(workspace, company: company, first_name: "Bob") }

  def build_relationship(from:, to:, type:)
    described_class.new(from_person: from, to_person: to, relationship_type: type)
  end

  it "is valid with distinct people in the same workspace" do
    relationship = build_relationship(from: alice, to: bob, type: "invited")

    expect(relationship).to be_valid
  end

  it "rejects self links" do
    relationship = build_relationship(from: alice, to: alice, type: "invited")

    expect(relationship).not_to be_valid
    expect(relationship.errors[:to_person]).to include(I18n.t("activerecord.errors.messages.cannot_be_same_person"))
  end

  it "rejects people from different workspaces" do
    other_workspace = Workspace.create!(name: "Other", slug: "other-#{SecureRandom.hex(3)}")
    outsider = create_person!(other_workspace, company: create_company!(other_workspace))
    relationship = build_relationship(from: alice, to: outsider, type: "invited")

    expect(relationship).not_to be_valid
    expect(relationship.errors[:to_person]).to include(I18n.t("activerecord.errors.messages.must_belong_to_same_workspace"))
  end

  it "rejects duplicate symmetric pairs in the opposite direction" do
    described_class.create!(from_person: alice, to_person: bob, relationship_type: "worked_with")
    duplicate = build_relationship(from: bob, to: alice, type: "worked_with")

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:base]).to include(I18n.t("activerecord.errors.messages.relationship_exists_opposite"))
  end

  describe "#label_for" do
    it "shows forward and inverse labels for directed types" do
      relationship = described_class.create!(from_person: alice, to_person: bob, relationship_type: "invited")

      expect(relationship.label_for(alice)).to eq(I18n.t("people.relationships.types.invited.from"))
      expect(relationship.label_for(bob)).to eq(I18n.t("people.relationships.types.invited.to"))
    end

    it "shows the same label on both sides for symmetric types" do
      relationship = described_class.create!(from_person: alice, to_person: bob, relationship_type: "colleague_of")

      expect(relationship.label_for(alice)).to eq(I18n.t("people.relationships.types.colleague_of.from"))
      expect(relationship.label_for(bob)).to eq(I18n.t("people.relationships.types.colleague_of.to"))
    end
  end

  describe "#other_person" do
    it "returns the opposite person for each side" do
      relationship = described_class.create!(from_person: alice, to_person: bob, relationship_type: "referred_by")

      expect(relationship.other_person(alice)).to eq(bob)
      expect(relationship.other_person(bob)).to eq(alice)
    end
  end
end
