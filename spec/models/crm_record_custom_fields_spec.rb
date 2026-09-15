require "rails_helper"

RSpec.describe "CrmRecord custom fields", type: :model do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  before do
    Current.session = users(:one).sessions.create!
    Current.workspace = workspace
  end

  it "persists custom field values and logs activity" do
    workspace.custom_fields.create!(record_type: "Company", name: "Vertical", field_type: "text")

    expect {
      company.update!(custom_fields: {"vertical" => "Enterprise"})
    }.to change(CustomFieldValue, :count).by(1)
      .and change { company.activities.where(action: "updated").count }.by(1)

    expect(company.reload.custom_fields_hash["vertical"]).to eq("Enterprise")
  end

  it "validates required custom fields" do
    workspace.custom_fields.create!(record_type: "Company", name: "Vertical", field_type: "text", required: true)

    company.custom_fields = {"vertical" => ""}

    expect(company).not_to be_valid
    expect(company.errors[:base]).to include("Vertical is required")
  end

  describe ".apply_custom_field_filters" do
    it "returns only records matching the filter value" do
      field = workspace.custom_fields.create!(record_type: "Company", name: "Tier",
        field_type: "select", options: %w[Gold Silver])
      gold = workspace.companies.create!(name: "Gold Co")
      gold.update!(custom_fields: {field.key => "Gold"})
      silver = workspace.companies.create!(name: "Silver Co")
      silver.update!(custom_fields: {field.key => "Silver"})

      result = Company.apply_custom_field_filters(workspace, {field.key => "Gold"})

      expect(result).to include(gold)
      expect(result).not_to include(silver)
    end

    it "ignores blank and unknown keys" do
      result = Company.apply_custom_field_filters(workspace, {"nope" => "x", "tier" => ""})

      expect(result).to include(company)
    end
  end

  describe ".sorted_by_custom_field" do
    it "orders by the custom field value with missing values last" do
      field = workspace.custom_fields.create!(record_type: "Company", name: "Rank", field_type: "text")
      a = workspace.companies.create!(name: "A Co")
      a.update!(custom_fields: {field.key => "alpha"})
      b = workspace.companies.create!(name: "B Co")
      b.update!(custom_fields: {field.key => "beta"})
      missing = workspace.companies.create!(name: "No value Co")

      ordered = Company.where(id: [a.id, b.id, missing.id])
        .sorted_by_custom_field(workspace, field.key, :asc).to_a

      expect(ordered.index(a)).to be < ordered.index(b)
      expect(ordered.last).to eq(missing)
    end
  end
end
