require "rails_helper"

RSpec.describe "Api::V1::Marketing", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:token) { admin.api_tokens.create!(name: "API", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }
  let(:sales_headers) do
    {"Authorization" => "Bearer #{salesperson.api_tokens.create!(name: "Sales", workspace: workspace).plaintext_token}"}
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_campaigns).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_segments).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:lead_scoring).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_attribution).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:email_templates).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  describe "GET /api/v1/marketing/mqls" do
    it "lists eligible MQLs for workspace members" do
      person = create_person!(workspace, email: "api-mql@example.com")
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      get "/api/v1/marketing/mqls", headers: sales_headers

      expect(response).to have_http_status(:success)
      emails = response.parsed_body.map { |row| row["email"] }
      expect(emails).to include("api-mql@example.com")
    end
  end

  describe "GET /api/v1/people/:id/marketing" do
    it "returns marketing context for a person" do
      person = create_person!(workspace, email: "ctx@example.com", lead_score: 10)
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      get "/api/v1/people/#{person.id}/marketing", headers: headers

      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body["person_id"]).to eq(person.id)
      expect(body["marketing_eligible"]).to be(true)
    end
  end

  describe "POST /api/v1/marketing/mql_conversions" do
    let(:pipeline) { Pipeline.create_default!(workspace) }
    let(:product) { workspace.products.create!(name: "API Product", price: 10) }
    let(:person) { create_person!(workspace, email: "convert-api@example.com") }
    let!(:interest) do
      Marketing::ProductInterest.create!(
        workspace: workspace,
        person: person,
        product: product,
        description: "Interested",
        source_kind: "manual",
        occurred_at: Time.current
      )
    end

    before do
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )
    end

    it "creates a deal from a product interest" do
      post "/api/v1/marketing/mql_conversions",
        params: {
          conversion: {
            product_interest_id: interest.id,
            pipeline_id: pipeline.id,
            task_title: "Follow up",
            task_due_on: (Date.current + 2.days).to_s
          }
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["status"]).to eq("created")
      expect(response.parsed_body["deal"]["name"]).to be_present
    end
  end

  describe "POST /api/v1/marketing/campaigns/:campaign_id/sends" do
    it "queues CampaignSendJob when campaign has inline content" do
      campaign = workspace.campaigns.create!(
        name: "API Campaign",
        status: "draft",
        email_subject: "Hi",
        email_body: "Hello"
      )
      segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

      expect {
        post "/api/v1/marketing/campaigns/#{campaign.id}/sends",
          params: {
            campaign_send: {
              segment_id: segment.id
            }
          },
          headers: headers,
          as: :json
      }.to have_enqueued_job(CampaignSendJob)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["queued"]).to be(true)
    end

    it "returns 422 when campaign has no email content" do
      campaign = workspace.campaigns.create!(name: "Empty", status: "draft")
      segment = workspace.segments.create!(name: "All", record_type: "Person", user: admin, filters: {})

      post "/api/v1/marketing/campaigns/#{campaign.id}/sends",
        params: {campaign_send: {segment_id: segment.id}},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/marketing/campaigns" do
    it "forbids salespeople" do
      workspace.campaigns.create!(name: "Hidden", status: "draft")

      get "/api/v1/marketing/campaigns", headers: sales_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/people/:id/subscription" do
    it "subscribes a person" do
      person = create_person!(workspace, email: "sub-api@example.com")
      type = workspace.subscription_types.find_by!(slug: "newsletter")

      patch "/api/v1/people/#{person.id}/subscription",
        params: {subscription: {subscription_type_id: type.id, action: "subscribe"}},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["subscription"]["status"]).to eq("subscribed")
    end
  end
end
