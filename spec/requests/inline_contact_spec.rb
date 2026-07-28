require "rails_helper"

RSpec.describe "Inline contact creation", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  it "lists a company's people as JSON" do
    sign_in_as(member)
    company = create_company!(workspace)
    inside = create_person!(workspace, company: company, first_name: "Inside")
    create_person!(workspace, company: create_company!(workspace), first_name: "Outside")

    get people_path(format: :json, company_id: company.id)

    expect(response).to have_http_status(:success)
    names = JSON.parse(response.body).map { |p| p["name"] }
    expect(names).to include(inside.display_name)
    expect(names.join).not_to include("Outside")
  end

  it "creates a contact in a company via JSON" do
    sign_in_as(member)
    company = create_company!(workspace)

    expect {
      post people_path(format: :json), params: { person: { first_name: "Nadia", last_name: "Khan", company_id: company.id } }
    }.to change(company.people, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["name"]).to eq("Nadia Khan")
    expect(body["id"]).to be_present
  end

  it "renders the deal form with the deal-contacts controller" do
    sign_in_as(member)
    Pipeline.create_default!(workspace)

    get new_deal_path
    expect(response.body).to include('data-controller="deal-contacts"')
    expect(response.body).to include('data-controller="record-picker"')
    expect(response.body).to include('data-deal-contacts-target="companySelect"')
    expect(response.body).to include('data-deal-contacts-target="broughtBy"')
  end
end
