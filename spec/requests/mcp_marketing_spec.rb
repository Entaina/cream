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

  let(:marketing_tool_names) do
    %w[
      list_mqls get_person_marketing list_product_interests list_subscription_types list_subscriptions
      list_campaigns get_campaign list_segments get_segment list_journeys get_journey
      list_scoring_rules get_attribution list_email_templates list_lead_forms
      create_mql create_product_interest convert_mql_to_sql set_subscription enroll_in_journey
      send_campaign cancel_campaign_send
    ]
  end

  describe "tools/list" do
    it "includes marketing tools" do
      post mcp_url, params: tools_list_payload, as: :json, headers: mcp_headers(plaintext)

      names = JSON.parse(response.body).dig("result", "tools").map { |t| t["name"] }
      expect(names).to include(*marketing_tool_names)
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
      journey.steps.create!(position: 0, step_type: "wait", config: {"days" => 1})
      person = create_person!(workspace, email: "enroll@example.com")

      result = mcp_tool_error("enroll_in_journey", {journey_id: journey.id, person_id: person.id}, token: sales_token)

      expect(result["error"]).to eq("not_found")
    end
  end

  describe "create_mql" do
    let(:product) { workspace.products.create!(name: "Workshop", price: 50) }
    let(:arguments) do
      {
        email: "Mcp.Lead@Example.com", first_name: "Mcp", last_name: "Lead", company_name: "Lead Corp",
        internal_notes: "Met at expo",
        subscriptions: [{
          subscription_type_id: workspace.subscription_types.find_by!(slug: "general").id,
          consent_text: "I accept marketing emails", consent_source: "Expo 2026 signup sheet"
        }],
        notes: [{title: "Intro", body: "Warm lead"}],
        attachments: [{filename: "brief.txt", content: Base64.strict_encode64("hello")}],
        product_id: product.id, interest_description: "Wants a workshop"
      }
    end

    it "registers an MQL with consent, notes, attachments and an interest" do
      result = call_tool("create_mql", arguments, token: sales_token)

      expect(result["created"]).to include(
        "email" => "mcp.lead@example.com", "lifecycle_stage" => "mql", "marketing_eligible" => true,
        "internal_notes" => "Met at expo"
      )
      person = workspace.people.find(result.dig("created", "id"))
      expect(person.notes.pluck(:body)).to eq(["Warm lead"])
      expect(person.record_attachments.map { |a| a.file.filename.to_s }).to eq(["brief.txt"])
      expect(person.product_interests.pluck(:description)).to eq(["Wants a workshop"])
      expect(person.email_subscriptions.first).to have_attributes(status: "subscribed", source: "mcp")
      expect(result.dig("created", "subscriptions", 0, "consent_evidence")).to include(
        "marketing_consent_text" => "I accept marketing emails",
        "consent_source" => "Expo 2026 signup sheet",
        "recorded_by" => salesperson.name
      )
    end

    it "requires subscriptions with their consent evidence" do
      entry = arguments[:subscriptions].first
      missing = call_tool_raw("create_mql", arguments.except(:subscriptions))
      no_evidence = call_tool_raw("create_mql", arguments.merge(subscriptions: [entry.except(:consent_text, :consent_source)]))
      blank = mcp_tool_error("create_mql", arguments.merge(subscriptions: [entry.merge(consent_text: " ")]))
      empty = call_tool_raw("create_mql", arguments.merge(subscriptions: []))

      expect(JSON.parse(missing.body).dig("result", "content", 0, "text")).to include("subscriptions")
      expect(JSON.parse(no_evidence.body).dig("result", "content", 0, "text")).to include("consent_text", "consent_source")
      expect(JSON.parse(empty.body).dig("result", "content", 0, "text")).to include("subscriptions")
      expect(blank["error"]).to eq("invalid_argument")
      expect(blank["message"]).to eq(I18n.t("marketing.consent_evidence.errors.consent_text_required"))
      expect(workspace.people.with_email("mcp.lead@example.com")).to be_empty
    end

    it "reports invalid attachments" do
      result = mcp_tool_error("create_mql", arguments.merge(attachments: [{filename: "x.txt", content: "***"}]))

      expect(result["error"]).to eq("invalid_attachment")
      expect(workspace.people.with_email("mcp.lead@example.com")).to be_empty
    end

    it "returns feature_unavailable when mql_pool is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(false)

      expect(mcp_tool_error("create_mql", arguments)["error"]).to eq("feature_unavailable")
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
      first = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal A")
      second = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [person], name: "Deal B")
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
      campaign = workspace.campaigns.create!(
        name: "Launch",
        status: "draft",
        email_subject: "Hello",
        email_body: "Hello body"
      )
      segment = workspace.segments.create!(
        name: "Everyone",
        record_type: "Person",
        user: admin,
        filters: {}
      )
      person = create_person!(workspace, email: "send@example.com")
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      expect {
        result = call_tool("send_campaign", {
          campaign_id: campaign.id,
          segment_id: segment.id
        })
        expect(result["queued"]).to be(true)
      }.to have_enqueued_job(CampaignSendJob)
    end
  end

  describe "list_subscriptions" do
    let(:general) { workspace.subscription_types.find_by!(slug: "general") }
    let(:newsletter) { workspace.subscription_types.find_by!(slug: "newsletter") }
    let!(:ana) { create_person!(workspace, first_name: "Ana", email: "ana@example.com") }
    let!(:bob) { create_person!(workspace, first_name: "Bob", email: "bob@example.com") }

    before do
      Marketing::ConsentService.subscribe!(
        person: ana, subscription_type: general, source: "mcp", legal_basis: "consent",
        metadata: {"marketing_consent_text" => "I agree"}
      )
      Marketing::ConsentService.subscribe!(person: bob, subscription_type: newsletter, source: "mcp", legal_basis: "consent")
      Marketing::ConsentService.unsubscribe!(person: bob, subscription_type: newsletter, source: "mcp")
    end

    it "lists the workspace subscriptions with the person and the consent evidence" do
      result = call_tool("list_subscriptions", {}, token: sales_token)

      expect(result["subscriptions"].map { |row| row.dig("person", "email") }).to contain_exactly("ana@example.com", "bob@example.com")
      ana_row = result["subscriptions"].find { |row| row.dig("person", "id") == ana.id }
      expect(ana_row).to include("status" => "subscribed", "slug" => "general")
      expect(ana_row["consent_evidence"]).to include("marketing_consent_text" => "I agree")
    end

    it "filters by subscription type, status and person" do
      by_type = call_tool("list_subscriptions", {subscription_type_id: newsletter.id})
      by_status = call_tool("list_subscriptions", {status: "subscribed"})
      by_person = call_tool("list_subscriptions", {person_id: bob.id})

      expect(by_type["subscriptions"].map { |row| row.dig("person", "id") }).to eq([bob.id])
      expect(by_status["subscriptions"].map { |row| row.dig("person", "id") }).to eq([ana.id])
      expect(by_person["subscriptions"].map { |row| row["status"] }).to eq(["unsubscribed"])
    end

    it "does not list subscriptions of other workspaces" do
      stranger = create_person!(other_workspace, email: "stranger@example.com")
      Marketing::ConsentService.subscribe!(
        person: stranger, subscription_type: other_workspace.subscription_types.first, source: "mcp", legal_basis: "consent"
      )

      result = call_tool("list_subscriptions", {})

      expect(result["subscriptions"].map { |row| row.dig("person", "email") }).not_to include("stranger@example.com")
    end

    it "returns feature_unavailable when marketing consent is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(false)

      expect(mcp_tool_error("list_subscriptions", {})["error"]).to eq("feature_unavailable")
    end
  end

  describe "set_subscription" do
    let(:person) { create_person!(workspace, email: "sub@example.com") }
    let(:type) { workspace.subscription_types.find_by!(slug: "newsletter") }
    let(:arguments) do
      {
        person_id: person.id, subscription_type_id: type.id, action: "subscribe",
        consent_text: "I agree to the newsletter", consent_source: "https://example.com/signup",
        consent_obtained_at: "2026-10-01T09:30:00Z", consent_ip: "203.0.113.7"
      }
    end

    it "subscribes a person via ConsentService and stores the consent evidence" do
      result = call_tool("set_subscription", arguments)

      expect(result["action"]).to eq("subscribe")
      expect(result["subscription"]["status"]).to eq("subscribed")
      expect(result["subscription"]["consent_evidence"]).to include(
        "marketing_consent_text" => "I agree to the newsletter",
        "consent_source" => "https://example.com/signup",
        "consent_ip" => "203.0.113.7",
        "recorded_by_user_id" => admin.id
      )
      expect(EmailSubscription.find_by!(person: person, subscription_type: type).subscribed?).to be(true)
    end

    it "requires the consent text and source to subscribe" do
      %i[consent_text consent_source].each do |field|
        result = mcp_tool_error("set_subscription", arguments.except(field))

        expect(result["error"]).to eq("invalid_argument")
        expect(result["message"]).to eq(I18n.t("marketing.consent_evidence.errors.#{field}_required"))
      end
      expect(EmailSubscription.where(person: person, subscription_type: type)).to be_empty
    end

    it "keeps the original evidence when the person is already subscribed" do
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "lead_form:signup", legal_basis: "consent",
        metadata: {"marketing_consent_text" => "Original text"}
      )

      call_tool("set_subscription", arguments)

      subscription = EmailSubscription.find_by!(person: person, subscription_type: type)
      expect(subscription.source).to eq("lead_form:signup")
      expect(subscription.consent_evidence).to eq("marketing_consent_text" => "Original text")
    end

    it "does not require evidence to unsubscribe" do
      result = call_tool("set_subscription", arguments.slice(:person_id, :subscription_type_id).merge(action: "unsubscribe"))

      expect(result["action"]).to eq("unsubscribe")
    end
  end

  describe "get_person_marketing" do
    it "returns marketing context for a person" do
      person = create_person!(workspace, email: "context@example.com", lead_score: 42)
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "spec", legal_basis: "consent"
      )

      result = call_tool("get_person_marketing", {person_id: person.id})

      expect(result["person_id"]).to eq(person.id)
      expect(result["lead_score"]).to eq(42)
      expect(result["subscriptions"].first["slug"]).to eq("general")
      expect(result["marketing_eligible"]).to be(true)
    end
  end
end
