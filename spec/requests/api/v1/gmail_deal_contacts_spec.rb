require "rails_helper"

RSpec.describe "Api::V1::GmailDealContacts", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let!(:deal) { create_deal!(workspace, company: company) }

  describe "POST /api/v1/gmail/deals/:deal_id/contacts" do
    it "adds a contact to the deal" do
      post "/api/v1/gmail/deals/#{deal.id}/contacts",
        params: {contacts: [{email: "partner@acme.com", name: "Partner Person"}]},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["contact_emails"]).to include("partner@acme.com")
      expect(deal.reload.contacts.map(&:email)).to include("partner@acme.com")
    end

    it "returns 422 when the person belongs to another company" do
      other_company = workspace.companies.create!(name: "Other Co")
      create_person!(workspace, company: other_company, email: "outsider@other.com")

      post "/api/v1/gmail/deals/#{deal.id}/contacts",
        params: {contacts: [{email: "outsider@other.com"}]},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["errors"].first).to include("another company")
      expect(body["email"]).to eq("outsider@other.com")
    end

    it "returns 404 for a deal outside the workspace" do
      foreign = create_deal!(workspaces(:two))

      post "/api/v1/gmail/deals/#{foreign.id}/contacts",
        params: {contacts: [{email: "partner@acme.com"}]},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
