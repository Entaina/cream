require "rails_helper"

RSpec.describe "Api::V1::People", type: :request do
  fixtures :users, :workspaces, :memberships

  it "lists people with bearer token" do
    user = users(:one)
    workspace = workspaces(:one)
    token = user.api_tokens.create!(name: "Test", workspace: workspace)
    create_person!(workspace)

    get "/api/v1/people", headers: { "Authorization" => "Bearer #{token.plaintext_token}" }

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to be_an(Array)
  end
end
