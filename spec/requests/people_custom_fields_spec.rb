require "rails_helper"

RSpec.describe "People custom fields", type: :request do
  fixtures :users, :workspaces, :memberships, :companies, :custom_fields

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }

  before do
    sign_in_as(member)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  it "persists custom field values when updating a person" do
    person = create_person!(workspace, company: company)

    patch person_path(person), params: {
      person: { first_name: person.first_name, company_id: company.id, custom_fields: { customer_tier: "Gold" } }
    }

    expect(response).to redirect_to(person_path(person))
    expect(person.reload.custom_fields_hash["customer_tier"]).to eq("Gold")
  end

  it "filters the index by a custom field value" do
    gold = create_person!(workspace, company: company, first_name: "Goldie")
    gold.update!(custom_fields: { "customer_tier" => "Gold" })
    silver = create_person!(workspace, company: company, first_name: "Silvia")
    silver.update!(custom_fields: { "customer_tier" => "Silver" })

    get people_path(cf: { customer_tier: "Gold" })

    expect(response.body).to include("Goldie")
    expect(response.body).not_to include("Silvia")
  end

  it "sorts the index by a custom field" do
    get people_path(sort: "cf:customer_tier", dir: "asc")

    expect(response).to have_http_status(:success)
  end

  it "persists a record reference custom field value" do
    person = create_person!(workspace, company: company)
    other_company = workspace.companies.create!(name: "Beta Corp")

    patch person_path(person), params: {
      person: { first_name: person.first_name, company_id: company.id, custom_fields: { related_company: other_company.id } }
    }

    expect(response).to redirect_to(person_path(person))
    expect(person.reload.custom_fields_hash["related_company"]).to eq(other_company.id)
  end

  it "filters the index by a record reference custom field" do
    target = workspace.companies.create!(name: "Linked Co")
    other = workspace.companies.create!(name: "Other Co")
    linked = create_person!(workspace, company: company, first_name: "Linked")
    linked.update!(custom_fields: { "related_company" => target.id })
    unlinked = create_person!(workspace, company: company, first_name: "Unlinked")
    unlinked.update!(custom_fields: { "related_company" => other.id })

    get people_path(cf: { related_company: target.id })

    expect(response.body).to include("Linked")
    expect(response.body).not_to include("Unlinked")
  end

  it "removes record reference values when the referenced record is deleted" do
    person = create_person!(workspace, company: company)
    target = workspace.companies.create!(name: "Gone Co")
    person.update!(custom_fields: { "related_company" => target.id })

    expect {
      target.destroy
    }.to change {
      CustomFieldValue.joins(:custom_field).where(custom_fields: { key: "related_company" }).count
    }.from(1).to(0)
  end
end
