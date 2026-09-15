require "rails_helper"

RSpec.describe "Inline company creation", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }

  it "creates a company via JSON and returns id/name" do
    sign_in_as(member)

    expect {
      post companies_path(format: :json), params: {company: {name: "Globex"}}
    }.to change(workspaces(:one).companies, :count).by(1)

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["name"]).to eq("Globex")
    expect(body["id"]).to be_present
  end

  it "returns errors as JSON when invalid" do
    sign_in_as(member)
    post companies_path(format: :json), params: {company: {name: ""}}
    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to be_present
  end

  it "renders the company picker with search and on-the-fly creation on the deal and person forms" do
    sign_in_as(member)
    Pipeline.create_default!(workspaces(:one))

    get new_deal_path
    expect(response.body).to include('data-controller="record-picker"')
    expect(response.body).to include("data-record-picker-create-url-value")

    get new_person_path
    expect(response.body).to include('data-controller="record-picker"')
    expect(response.body).to include("data-record-picker-create-url-value")
  end
end
