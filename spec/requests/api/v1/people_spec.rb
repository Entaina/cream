require "rails_helper"

RSpec.describe "Api::V1::People", type: :request do
  fixtures :users, :workspaces, :memberships

  it "lists people with bearer token" do
    user = users(:one)
    workspace = workspaces(:one)
    token = user.api_tokens.create!(name: "Test", workspace: workspace)
    person = create_person!(workspace)

    get "/api/v1/people", headers: { "Authorization" => "Bearer #{token.plaintext_token}" }

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body).to be_an(Array)
    expect(body.first).to include(
      "created_at" => person.created_at.iso8601,
      "updated_at" => person.updated_at.iso8601
    )
  end

  it "filters people by exact email" do
    user = users(:one)
    workspace = workspaces(:one)
    token = user.api_tokens.create!(name: "Test", workspace: workspace)
    company = workspace.companies.create!(name: "Acme", owner: user)
    match = create_person!(workspace, company: company, email: "ana@example.com", first_name: "Ana")
    create_person!(workspace, company: company, email: "ana.other@example.com", first_name: "Other")
    create_person!(workspace, company: company, email: "bob@example.com", first_name: "Bob")

    get "/api/v1/people",
      params: { email: "Ana@Example.com" },
      headers: { "Authorization" => "Bearer #{token.plaintext_token}" }

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body.map { |person| person["id"] }).to eq([ match.id ])
  end

  it "filters people by exact secondary email" do
    user = users(:one)
    workspace = workspaces(:one)
    token = user.api_tokens.create!(name: "Test", workspace: workspace)
    company = workspace.companies.create!(name: "Acme", owner: user)
    match = create_person!(workspace, company: company, email: "primary@example.com", first_name: "Ana")
    match.add_email!("alias@example.com")
    create_person!(workspace, company: company, email: "other@example.com", first_name: "Other")

    get "/api/v1/people",
      params: { email: "alias@example.com" },
      headers: { "Authorization" => "Bearer #{token.plaintext_token}" }

    expect(response).to have_http_status(:success)
    body = response.parsed_body
    expect(body.map { |person| person["id"] }).to eq([ match.id ])
  end
end
