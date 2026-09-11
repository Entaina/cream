require "rails_helper"

RSpec.describe "Mcp marketing tools", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }
  let(:other_workspace) { workspaces(:two) }
  let(:token) { admin.api_tokens.create!(name: "Admin MCP", workspace: workspace) }
  let(:plaintext) { token.plaintext_token }
  let(:sales_token) do
    salesperson.api_tokens.create!(name: "Sales MCP", workspace: workspace).plaintext_token
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
    SubscriptionType.ensure_defaults!(other_workspace)
  end

  MARKETING_TOOL_NAMES = %w[
    list_mqls get_person_marketing list_product_interests list_subscription_types
    list_campaigns get_campaign list_segments get_segment list_journeys get_journey
    list_scoring_rules get_attribution list_email_templates list_lead_forms
    create_product_interest convert_mql_to_sql set_subscription enroll_in_journey
    send_campaign cancel_campaign_send
  ].freeze

  describe "tools/list" do
    it "includes marketing tools" do
      post mcp_url, params: tools_list_payload, as: :json, headers: mcp_headers(plaintext)

      names = JSON.parse(response.body).dig("result", "tools").map { |t| t["name"] }
      expect(names).to include(*MARKETING_TOOL_NAMES)
    end
  end

  describe "feature flags" do
    it "returns feature_unavailable when mql_pool is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(false)

      result = mcp_tool_error("list_mqls", {})

      expect(result["error"]).to eq("feature_unavailable")
    end
  end

  describe "list_mqls" do
    it "lists eligible contacts for any workspace member" do
      person = create_person!(workspace, email: "mcp-mql@example.com")
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      result = call_tool("list_mqls", {}, token: sales_token)

      emails = result["mqls"].map { |row| row["email"] }
      expect(emails).to include("mcp-mql@example.com")
    end

    it "does not leak MQLs from another workspace" do
      person = create_person!(other_workspace, email: "hidden-mql@example.com")
      type = other_workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      result = call_tool("list_mqls", {})

      emails = result["mqls"].map { |row| row["email"] }
      expect(emails).not_to include("hidden-mql@example.com")
    end
  end

  describe "authorization" do
    it "forbids salespeople from listing campaigns" do
      workspace.campaigns.create!(name: "Secret", status: "draft")

      result = mcp_tool_error("list_campaigns", {}, token: sales_token)

      expect(result["error"]).to eq("forbidden")
    end

    it "forbids salespeople from enrolling in journeys" do
      journey = workspace.journeys.create!(name: "Flow", entry_trigger: "manual", active: true)
      journey.steps.create!(position: 0, step_type: "wait", config: { "days" => 1 })
      person = create_person!(workspace, email: "enroll@example.com")

      result = mcp_tool_error("enroll_in_journey", { journey_id: journey.id, person_id: person.id }, token: sales_token)

      expect(result["error"]).to eq("not_found")
    end
  end

  describe "convert_mql_to_sql" do
    let(:pipeline) { Pipeline.create_default!(workspace) }
    let(:product) { workspace.products.create!(name: "Workshop", price: 50) }
    let(:person) { create_person!(workspace, email: "convert-mcp@example.com") }
    let!(:interest) do
      Marketing::ProductInterest.create!(
        workspace: workspace,
        person: person,
        product: product,
        description: "Asked about workshop",
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

    it "creates a deal with a next task" do
      result = call_tool("convert_mql_to_sql", {
        product_interest_id: interest.id,
        pipeline_id: pipeline.id,
        task_title: "Follow up",
        task_due_on: (Date.current + 3.days).to_s
      })

      expect(result["status"]).to eq("created")
      expect(result["deal"]["name"]).to be_present
      expect(interest.reload.status).to eq("converted")
    end

    it "returns conflict when multiple open deals exist for the product" do
      first = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [ person ], name: "Deal A")
      second = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [ person ], name: "Deal B")
      first.deal_products.create!(product: product, quantity: 1)
      second.deal_products.create!(product: product, quantity: 1)

      result = call_tool("convert_mql_to_sql", {
        product_interest_id: interest.id,
        pipeline_id: pipeline.id,
        task_title: "Follow up",
        task_due_on: (Date.current + 3.days).to_s
      })

      expect(result["status"]).to eq("conflict")
    end
  end

  describe "send_campaign" do
    it "queues CampaignSendJob without calling the ESP" do
      campaign = workspace.campaigns.create!(name: "Launch", status: "draft")
      segment = workspace.segments.create!(
        name: "Everyone",
        record_type: "Person",
        user: admin,
        filters: {}
      )
      template = workspace.email_templates.create!(
        name: "Tpl",
        body: "Hello",
        user: admin
      )
      person = create_person!(workspace, email: "send@example.com")
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      expect {
        result = call_tool("send_campaign", {
          campaign_id: campaign.id,
          segment_id: segment.id,
          email_template_id: template.id
        })
        expect(result["queued"]).to be(true)
      }.to have_enqueued_job(CampaignSendJob)
    end
  end

  describe "set_subscription" do
    it "subscribes a person via ConsentService" do
      person = create_person!(workspace, email: "sub@example.com")
      type = workspace.subscription_types.find_by!(slug: "newsletter")

      result = call_tool("set_subscription", {
        person_id: person.id,
        subscription_type_id: type.id,
        action: "subscribe"
      })

      expect(result["action"]).to eq("subscribe")
      expect(result["subscription"]["status"]).to eq("subscribed")
      expect(EmailSubscription.find_by!(person: person, subscription_type: type).subscribed?).to be(true)
    end
  end

  describe "get_person_marketing" do
    it "returns marketing context for a person" do
      person = create_person!(workspace, email: "context@example.com", lead_score: 42)
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      result = call_tool("get_person_marketing", { person_id: person.id })

      expect(result["person_id"]).to eq(person.id)
      expect(result["lead_score"]).to eq(42)
      expect(result["subscriptions"].first["slug"]).to eq("general")
      expect(result["marketing_eligible"]).to be(true)
    end
  end
end
