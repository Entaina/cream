require "rails_helper"

RSpec.describe CompanyMerger do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  before do
    Current.session = user.sessions.create!
    Current.workspace = workspace
  end

  def merge(primary:, secondaries:)
    described_class.call(primary: primary, secondaries: secondaries, user: user)
  end

  it "reassigns people, deals and notes to the primary company" do
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    person = create_person!(workspace, company: secondary, email: "pat@mapfre.com")
    deal = create_deal!(workspace, company: secondary, contacts: [person])
    note = secondary.notes.create!(body: "Met at conference", user: user, workspace: workspace)

    result = merge(primary: primary, secondaries: [secondary])

    expect(result).to eq(primary)
    expect(Company.exists?(secondary.id)).to be(false)
    expect(person.reload.company).to eq(primary)
    expect(deal.reload.company).to eq(primary)
    expect(note.reload.notable).to eq(primary)
  end

  it "merges people with the same email into one contact" do
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    primary_person = create_person!(workspace, company: primary, first_name: "Primary", email: "pat@mapfre.com")
    secondary_person = create_person!(workspace, company: secondary, first_name: "Secondary", email: "pat@mapfre.com")

    merge(primary: primary, secondaries: [secondary])

    expect(Person.exists?(secondary_person.id)).to be(false)
    expect(primary.people.pluck(:email)).to eq(["pat@mapfre.com"])
    expect(primary_person.reload.first_name).to eq("Primary")
  end

  it "deduplicates list entries when both companies are on the same list" do
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    list = workspace.lists.create!(name: "Targets", record_type: "Company")
    list.list_entries.create!(record: primary)
    list.list_entries.create!(record: secondary)

    merge(primary: primary, secondaries: [secondary])

    expect(ListEntry.where(list_id: list.id, record_type: "Company", record_id: primary.id).count).to eq(1)
    expect(ListEntry.where(record_id: secondary.id)).to be_empty
    expect(primary.lists).to include(list)
  end

  it "keeps primary scalar values and fills blanks from the secondary" do
    primary = workspace.companies.create!(name: "Mapfre", domain: "mapfre.com")
    secondary = workspace.companies.create!(name: "Mapfre España", industry: "Insurance", location: "Madrid")

    merge(primary: primary, secondaries: [secondary])

    primary.reload
    expect(primary.domain).to eq("mapfre.com")
    expect(primary.industry).to eq("Insurance")
    expect(primary.location).to eq("Madrid")
  end

  it "merges custom field values, keeping the primary when both have values" do
    field = workspace.custom_fields.create!(record_type: "Company", name: "Tier", field_type: "text")
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    primary.update!(custom_fields: {field.key => "Gold"})
    secondary.update!(custom_fields: {field.key => "Silver"})

    merge(primary: primary, secondaries: [secondary])

    expect(primary.reload.custom_fields_hash[field.key]).to eq("Gold")
  end

  it "fills blank primary custom field values from the secondary" do
    field = workspace.custom_fields.create!(record_type: "Company", name: "Region", field_type: "text")
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    secondary.update!(custom_fields: {field.key => "EMEA"})

    merge(primary: primary, secondaries: [secondary])

    expect(primary.reload.custom_fields_hash[field.key]).to eq("EMEA")
  end

  it "updates record reference custom fields pointing at the secondary" do
    field = workspace.custom_fields.create!(record_type: "Deal", name: "Parent company", field_type: "record_reference",
      reference_type: "Company")
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")
    deal = create_deal!(workspace, company: primary)
    deal.update!(custom_fields: {field.key => secondary.id})

    merge(primary: primary, secondaries: [secondary])

    expect(deal.reload.custom_fields_hash[field.key]).to eq(primary.id)
  end

  it "rejects merging companies from different workspaces" do
    primary = create_company!(workspace, name: "Mapfre")
    other_workspace = Workspace.create!(name: "Other")
    secondary = other_workspace.companies.create!(name: "Mapfre España")

    expect {
      merge(primary: primary, secondaries: [secondary])
    }.to raise_error(CompanyMerger::Error, /same workspace/)
  end

  it "logs a merged activity on the primary company" do
    primary = create_company!(workspace, name: "Mapfre")
    secondary = create_company!(workspace, name: "Mapfre España")

    expect {
      merge(primary: primary, secondaries: [secondary])
    }.to change { primary.activities.where(action: "merged").count }.by(1)

    activity = primary.activities.where(action: "merged").last
    expect(activity.metadata["merged_companies"].first["name"]).to eq("Mapfre España")
  end
end
