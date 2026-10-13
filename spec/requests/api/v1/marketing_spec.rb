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

  describe "POST /api/v1/marketing/mqls" do
    let(:product) { workspace.products.create!(name: "API Product", price: 10) }
    let(:general) { workspace.subscription_types.find_by!(slug: "general") }
    let(:newsletter) { workspace.subscription_types.find_by!(slug: "newsletter") }
    let(:payload) do
      {
        mql: {
          email: "New.Lead@Example.com", first_name: "New", last_name: "Lead", company_name: "Lead Corp",
          internal_notes: "Asked for a demo",
          product_id: product.id, interest_description: "Wants the annual plan"
        },
        subscriptions: [{
          subscription_type_id: general.id, consent_text: "I agree to receive commercial communications",
          consent_source: "https://partner.example/signup", consent_obtained_at: "2026-10-01T09:30:00Z",
          consent_ip: "203.0.113.7"
        }],
        notes: [{title: "Call", body: "Spoke on the phone"}],
        attachments: [{filename: "brief.txt", content: Base64.strict_encode64("hello"), content_type: "text/plain"}]
      }
    end

    it "registers a new MQL with consent, notes, attachments and a product interest" do
      expect {
        post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers
      }.to change(workspace.people, :count).by(1)
        .and change(Company, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      person = workspace.people.find(body["id"])
      expect(person.email).to eq("new.lead@example.com")
      expect(person.lifecycle_stage).to eq("mql")
      expect(person.internal_notes).to eq("Asked for a demo")
      expect(person.notes.pluck(:body)).to eq(["Spoke on the phone"])
      expect(person.record_attachments.map { |a| a.file.filename.to_s }).to eq(["brief.txt"])
      expect(person.product_interests.pluck(:description)).to eq(["Wants the annual plan"])
      expect(body).to include("created" => true, "marketing_eligible" => true, "lifecycle_stage" => "mql")
      expect(body["attachments"].first).to include("filename" => "brief.txt", "byte_size" => 5)
      expect(body["subscriptions"]).to match([include("subscription_type_id" => general.id, "status" => "subscribed", "source" => "api")])
    end

    it "queues an outbound email with MQL registration when email is provided" do
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(false)

      expect {
        post "/api/v1/marketing/mqls",
          params: payload.merge(email: {subject: "Welcome", body: "Thanks for joining."}),
          as: :json,
          headers: sales_headers
      }.to change(EmailMessage, :count).by(1)
        .and have_enqueued_mail(RecordMailer, :tracked_email)

      person = workspace.people.find(response.parsed_body["id"])
      message = EmailMessage.order(:id).last
      expect(message.record).to eq(person)
      expect(response.parsed_body["sent_email"]).to include("subject" => "Welcome")
    end

    it "rolls back MQL registration when outbound email is invalid" do
      allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)

      expect {
        post "/api/v1/marketing/mqls",
          params: payload.merge(email: {subject: "Hi", body: ""}),
          as: :json,
          headers: sales_headers
      }.not_to change(workspace.people, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "stores the consent evidence and who registered it on the subscription" do
      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      subscription = workspace.people.find(response.parsed_body["id"]).email_subscriptions.first
      expect(subscription.legal_basis).to eq("consent")
      expect(subscription.consent_evidence).to eq(
        "marketing_consent_text" => "I agree to receive commercial communications",
        "consent_source" => "https://partner.example/signup",
        "consent_obtained_at" => "2026-10-01T09:30:00Z",
        "consent_ip" => "203.0.113.7",
        "recorded_by" => salesperson.name,
        "recorded_by_user_id" => salesperson.id
      )
      expect(response.parsed_body.dig("subscriptions", 0, "consent_evidence")).to eq(subscription.consent_evidence)
    end

    it "keeps the original evidence when the person is already subscribed" do
      person = create_person!(workspace, email: "new.lead@example.com")
      type = workspace.subscription_types.find_by!(slug: "general")
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "lead_form:signup", legal_basis: "consent",
        metadata: {"marketing_consent_text" => "Original text"}
      )

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(response).to have_http_status(:ok)
      subscription = person.email_subscriptions.first
      expect(subscription.source).to eq("lead_form:signup")
      expect(subscription.consent_evidence).to eq("marketing_consent_text" => "Original text")
    end

    it "rejects internal notes above the limit without creating anything" do
      too_long = "a" * (Person::INTERNAL_NOTES_MAX_LENGTH + 1)

      expect {
        post "/api/v1/marketing/mqls", params: payload.merge(mql: payload[:mql].merge(internal_notes: too_long)), as: :json, headers: sales_headers
      }.not_to change(workspace.people, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join).to include(Person.human_attribute_name(:internal_notes))
    end

    it "requires the consent text and source on every subscription" do
      %i[consent_text consent_source].each do |field|
        subscriptions = [payload[:subscriptions].first.except(field)]
        post "/api/v1/marketing/mqls", params: payload.merge(subscriptions: subscriptions), as: :json, headers: sales_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.consent_evidence.errors.#{field}_required")])
      end
      expect(workspace.people.with_email("new.lead@example.com")).to be_empty
    end

    it "validates the consent date and IP" do
      {
        {consent_obtained_at: 1.day.from_now.iso8601} => "consent_obtained_at_future",
        {consent_obtained_at: "yesterday-ish"} => "consent_obtained_at_invalid",
        {consent_ip: "not-an-ip"} => "consent_ip_invalid"
      }.each do |override, key|
        subscriptions = [payload[:subscriptions].first.merge(override)]
        post "/api/v1/marketing/mqls", params: payload.merge(subscriptions: subscriptions), as: :json, headers: sales_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.consent_evidence.errors.#{key}")])
      end
    end

    it "defaults the consent date to the registration time" do
      payload[:subscriptions].first.delete(:consent_obtained_at)

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      subscription = workspace.people.find(response.parsed_body["id"]).email_subscriptions.first
      expect(subscription.consent_evidence).not_to have_key("consent_obtained_at")
      expect(subscription.opted_in_at).to be_within(1.minute).of(Time.current)
    end

    it "reuses the person with the same email and keeps existing data" do
      company = create_company!(workspace, name: "Existing Corp")
      person = create_person!(workspace, company: company, email: "new.lead@example.com", first_name: "Old",
        internal_notes: "Previous note")

      expect {
        post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers
      }.not_to change(workspace.people, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["created"]).to be(false)
      person.reload
      expect(person.first_name).to eq("Old")
      expect(person.company).to eq(company)
      expect(person.lifecycle_stage).to eq("mql")
      expect(person.internal_notes).to eq("Previous note\n\nAsked for a demo")
    end

    it "does not demote a person who is already past the MQL stage" do
      person = create_person!(workspace, email: "new.lead@example.com", lifecycle_stage: "customer")

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(person.reload.lifecycle_stage).to eq("customer")
    end

    it "subscribes the person to several types, each with its own evidence" do
      payload[:subscriptions] << {subscription_type_id: newsletter.id, consent_text: "Newsletter opt-in", consent_source: "Expo sheet"}

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      person = workspace.people.find(response.parsed_body["id"])
      evidence = person.email_subscriptions.index_by(&:subscription_type_id).transform_values { |sub| sub.consent_evidence["marketing_consent_text"] }
      expect(evidence).to eq(
        general.id => "I agree to receive commercial communications", newsletter.id => "Newsletter opt-in"
      )
    end

    it "requires at least one subscription" do
      %i[subscriptions].each { |key| payload.delete(key) }

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.mql_creator.errors.subscriptions_required")])
      expect(workspace.people.with_email("new.lead@example.com")).to be_empty
    end

    it "rejects unknown, inactive, missing or repeated subscription types" do
      inactive = workspace.subscription_types.create!(name: "Old", slug: "old", active: false)
      entry = payload[:subscriptions].first
      {
        [entry.merge(subscription_type_id: 0)] => I18n.t("marketing.mql_creator.errors.subscription_type_not_found", id: 0),
        [entry.merge(subscription_type_id: inactive.id)] => I18n.t("marketing.mql_creator.errors.subscription_type_not_found", id: inactive.id),
        [entry.except(:subscription_type_id)] => I18n.t("marketing.mql_creator.errors.subscription_type_required"),
        [entry, entry] => I18n.t("marketing.mql_creator.errors.subscription_duplicated")
      }.each do |subscriptions, message|
        post "/api/v1/marketing/mqls", params: payload.merge(subscriptions: subscriptions), as: :json, headers: sales_headers

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to eq([message])
      end
      expect(workspace.people.with_email("new.lead@example.com")).to be_empty
    end

    it "requires an email and a company" do
      post "/api/v1/marketing/mqls", params: payload.merge(mql: payload[:mql].merge(email: "")), as: :json, headers: sales_headers
      expect(response).to have_http_status(:unprocessable_entity)

      post "/api/v1/marketing/mqls", params: payload.merge(mql: payload[:mql].except(:company_name)), as: :json, headers: sales_headers
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.mql_creator.errors.company_required")])
    end

    it "rolls everything back when an attachment is invalid" do
      payload[:attachments] = [{filename: "bad.txt", content: "not base64!"}]

      expect {
        post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers
      }.not_to change(workspace.people, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Marketing::ProductInterest.where(workspace: workspace)).to be_empty
    end

    it "rejects attachments when the attachments feature is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:attachments).and_return(false)

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(workspace.people.with_email("new.lead@example.com")).to be_empty
    end

    it "returns 404 when the MQL pool is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(false)

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(response).to have_http_status(:not_found)
    end

    it "does not use companies from other workspaces" do
      other_company = create_company!(workspaces(:two))
      payload[:mql] = payload[:mql].except(:company_name).merge(company_id: other_company.id)

      post "/api/v1/marketing/mqls", params: payload, as: :json, headers: sales_headers

      expect(response).to have_http_status(:not_found)
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

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/marketing/campaigns" do
    it "forbids salespeople" do
      workspace.campaigns.create!(name: "Hidden", status: "draft")

      get "/api/v1/marketing/campaigns", headers: sales_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/marketing/segments" do
    it "lists segments for admins" do
      workspace.segments.create!(name: "API segment", record_type: "Person", user: admin, filters: {})

      get "/api/v1/marketing/segments", headers: headers

      expect(response).to have_http_status(:success)
      names = response.parsed_body.map { |row| row["name"] }
      expect(names).to include("API segment")
    end
  end

  describe "GET /api/v1/marketing/scoring_rules" do
    before { workspace.update!(lead_scoring_enabled: true) }

    it "lists scoring rules for admins" do
      workspace.scoring_rules.create!(name: "Opens", points: 5, active: true)

      get "/api/v1/marketing/scoring_rules", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first["name"]).to eq("Opens")
    end
  end

  describe "GET /api/v1/people/:person_id/product_interests" do
    before do
      allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    end

    it "returns product interests for a person" do
      person = create_person!(workspace, email: "pi@example.com")
      product = workspace.products.create!(name: "Pro")
      Marketing::ProductInterest.create!(
        workspace: workspace,
        person: person,
        product: product,
        description: "Demo",
        source_kind: "manual",
        occurred_at: Time.current
      )

      get "/api/v1/people/#{person.id}/product_interests", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first["description"]).to eq("Demo")
    end
  end

  describe "GET /api/v1/marketing/attribution" do
    it "returns attribution rows for admins" do
      get "/api/v1/marketing/attribution", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include("rows", "totals")
    end
  end

  describe "GET /api/v1/marketing/subscriptions" do
    let(:general) { workspace.subscription_types.find_by!(slug: "general") }
    let(:newsletter) { workspace.subscription_types.find_by!(slug: "newsletter") }
    let!(:ana) { create_person!(workspace, first_name: "Ana", email: "ana@example.com") }
    let!(:bob) { create_person!(workspace, first_name: "Bob", email: "bob@example.com") }

    before do
      Marketing::ConsentService.subscribe!(
        person: ana, subscription_type: general, source: "api", legal_basis: "consent",
        metadata: {"marketing_consent_text" => "I agree", "consent_source" => "https://example.com/form"}
      )
      Marketing::ConsentService.subscribe!(person: bob, subscription_type: newsletter, source: "api", legal_basis: "consent")
      Marketing::ConsentService.unsubscribe!(person: bob, subscription_type: newsletter, source: "api")
    end

    it "lists the workspace subscriptions with the person and the consent evidence" do
      get "/api/v1/marketing/subscriptions", headers: sales_headers

      expect(response).to have_http_status(:success)
      rows = response.parsed_body
      expect(rows.map { |row| row["person"]["email"] }).to contain_exactly("ana@example.com", "bob@example.com")
      ana_row = rows.find { |row| row["person"]["id"] == ana.id }
      expect(ana_row).to include("status" => "subscribed", "slug" => "general", "subscription_type_id" => general.id)
      expect(ana_row["consent_evidence"]).to include("marketing_consent_text" => "I agree")
    end

    it "filters by subscription type, status and person" do
      get "/api/v1/marketing/subscriptions", params: {subscription_type_id: newsletter.id}, headers: headers
      expect(response.parsed_body.map { |row| row["person"]["id"] }).to eq([bob.id])

      get "/api/v1/marketing/subscriptions", params: {status: "subscribed"}, headers: headers
      expect(response.parsed_body.map { |row| row["person"]["id"] }).to eq([ana.id])

      get "/api/v1/marketing/subscriptions", params: {person_id: bob.id}, headers: headers
      expect(response.parsed_body.map { |row| row["status"] }).to eq(["unsubscribed"])
    end

    it "rejects an unknown status" do
      get "/api/v1/marketing/subscriptions", params: {status: "bogus"}, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.subscriptions.errors.invalid_status")])
    end

    it "does not list subscriptions of other workspaces" do
      other = workspaces(:two)
      SubscriptionType.ensure_defaults!(other)
      stranger = create_person!(other, email: "stranger@example.com")
      Marketing::ConsentService.subscribe!(
        person: stranger, subscription_type: other.subscription_types.first, source: "api", legal_basis: "consent"
      )

      get "/api/v1/marketing/subscriptions", headers: headers

      expect(response.parsed_body.map { |row| row["person"]["email"] }).not_to include("stranger@example.com")
    end

    it "returns not found when marketing consent is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(false)

      get "/api/v1/marketing/subscriptions", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/people/:id/subscription" do
    let(:person) { create_person!(workspace, email: "sub-api@example.com") }
    let(:type) { workspace.subscription_types.find_by!(slug: "newsletter") }
    let(:evidence) do
      {consent_text: "I agree to the newsletter", consent_source: "https://example.com/signup",
       consent_obtained_at: "2026-10-01T09:30:00Z", consent_ip: "203.0.113.7"}
    end

    def patch_subscription(subscription, as_headers: headers)
      patch "/api/v1/people/#{person.id}/subscription", params: {subscription: subscription}, headers: as_headers, as: :json
    end

    it "subscribes a person and stores the consent evidence with who registered it" do
      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence))

      expect(response).to have_http_status(:success)
      body = response.parsed_body["subscription"]
      expect(body["status"]).to eq("subscribed")
      expect(body["consent_evidence"]).to include(
        "marketing_consent_text" => "I agree to the newsletter",
        "consent_source" => "https://example.com/signup",
        "consent_ip" => "203.0.113.7",
        "recorded_by_user_id" => admin.id
      )
      expect(body["consent_evidence"]["consent_obtained_at"]).to eq("2026-10-01T09:30:00Z")
    end

    it "requires the consent text and source to subscribe" do
      %i[consent_text consent_source].each do |field|
        patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence.except(field)))

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.consent_evidence.errors.#{field}_required")])
      end
      expect(EmailSubscription.where(person: person, subscription_type: type)).to be_empty
    end

    it "validates the consent date and IP" do
      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence, consent_ip: "not-an-ip"))
      expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.consent_evidence.errors.consent_ip_invalid")])

      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence, consent_obtained_at: 1.day.from_now.iso8601))
      expect(response.parsed_body["errors"]).to eq([I18n.t("marketing.consent_evidence.errors.consent_obtained_at_future")])
    end

    it "keeps the original evidence when the person is already subscribed" do
      Marketing::ConsentService.subscribe!(
        person: person, subscription_type: type, source: "lead_form:signup", legal_basis: "consent",
        metadata: {"marketing_consent_text" => "Original text"}
      )

      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence))

      expect(response).to have_http_status(:success)
      subscription = EmailSubscription.find_by!(person: person, subscription_type: type)
      expect(subscription.source).to eq("lead_form:signup")
      expect(subscription.consent_evidence).to eq("marketing_consent_text" => "Original text")
    end

    it "replaces the evidence when a person subscribes again after unsubscribing" do
      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence, consent_text: "First"))
      patch_subscription({subscription_type_id: type.id, action: "unsubscribe"})
      patch_subscription({subscription_type_id: type.id, action: "subscribe"}.merge(evidence, consent_text: "Second"))

      subscription = EmailSubscription.find_by!(person: person, subscription_type: type)
      expect(subscription).to be_subscribed
      expect(subscription.consent_evidence["marketing_consent_text"]).to eq("Second")
    end

    it "does not require evidence to unsubscribe" do
      patch_subscription({subscription_type_id: type.id, action: "unsubscribe"})

      expect(response).to have_http_status(:success)
    end
  end
end
