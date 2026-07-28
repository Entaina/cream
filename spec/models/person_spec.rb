require "rails_helper"

RSpec.describe Person, type: :model do
  fixtures :workspaces, :users

  let(:workspace) { workspaces(:one) }

  it "requires a company" do
    person = workspace.people.new(first_name: "Pat")
    expect(person).not_to be_valid
    expect(person.errors[:company]).to be_present
  end

  it "is valid with a company" do
    person = workspace.people.new(first_name: "Pat", company: create_company!(workspace))
    expect(person).to be_valid
  end

  it "requires brought_by when source is team_member" do
    person = workspace.people.new(
      first_name: "Pat",
      company: create_company!(workspace),
      source: "team_member"
    )
    expect(person).not_to be_valid
    expect(person.errors[:brought_by_id]).to be_present
  end

  it "clears brought_by when source is not team_member" do
    person = workspace.people.new(
      first_name: "Pat",
      company: create_company!(workspace),
      source: "web_form",
      brought_by_id: users(:two).id
    )
    person.valid?
    expect(person.brought_by_id).to be_nil
  end
end
