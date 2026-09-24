require "rails_helper"

RSpec.describe "Api::V1::GmailThreads", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { companies(:acme) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }

  let(:thread_payload) do
    {
      gmail_thread_id: "thread-abc",
      messages: [
        {
          gmail_message_id: "msg-1",
          rfc822_message_id: "<msg-1@mail.example.com>",
          from: "client@example.com",
          to: user.email_address,
          subject: "Proposal follow-up",
          body: "Let's move forward.",
          sent_at: 2.days.ago.iso8601
        },
        {
          gmail_message_id: "msg-2",
          rfc822_message_id: "<msg-2@mail.example.com>",
          from: user.email_address,
          to: "client@example.com",
          subject: "Re: Proposal follow-up",
          body: "Great, sending the contract.",
          sent_at: 1.day.ago.iso8601
        }
      ]
    }
  end

  describe "POST /api/v1/gmail/threads/status" do
    it "returns linked deals for a known thread" do
      deal = create_deal!(
        workspace,
        company: company,
        name: "Linked opp",
        value: 1500,
        expected_close_date: Date.new(2026, 6, 15),
        owner: user
      )
      product = workspace.products.create!(name: "Curso X", price: 1500)
      edition = product.editions.create!(name: "Edición 2026", workspace: workspace)
      deal.deal_products.create!(product: product, edition: edition, quantity: 1)
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-abc",
        rfc822_message_id: "<msg-1@mail.example.com>"
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-abc",
          rfc822_message_ids: ["<msg-1@mail.example.com>"],
          participant_emails: ["client@example.com", user.email_address]
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      linked = body["linked"].find { |d| d["name"] == "Linked opp" }
      expect(linked).to include(
        "stage" => "Lead",
        "pipeline" => pipeline.name,
        "pipeline_id" => pipeline.id,
        "pipeline_stage_id" => deal.pipeline_stage_id,
        "company_name" => company.name,
        "value" => 1500.0,
        "currency" => "EUR",
        "owner_name" => user.name,
        "expected_close_date" => "2026-06-15",
        "products" => ["Curso X — Edición 2026"]
      )
      expect(linked["contacts"]).to be_present
      expect(linked["next_task"]).to include("title" => "Next action", "completed" => false)
      expect(linked["next_task"]["id"]).to be_present
      expect(linked["tasks"]).to be_an(Array)
      expect(linked["tasks"].first).to include("title" => "Next action", "completed" => false)
    end

    it "finds linked deals in another workspace the user belongs to" do
      other_workspace = workspaces(:two)
      Pipeline.create_default!(other_workspace)
      Membership.create!(user: user, workspace: other_workspace, role: "salesperson")
      deal = create_deal!(other_workspace, name: "Other workspace opp")
      other_workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-shared",
        rfc822_message_id: "<shared@mail.example.com>"
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-shared",
          rfc822_message_ids: ["<shared@mail.example.com>"],
          participant_emails: ["client@example.com"]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      linked = body["linked"].find { |d| d["name"] == "Other workspace opp" }
      expect(linked).to include("workspace_id" => other_workspace.id)
    end

    it "suggests deals whose contacts match thread participants" do
      person = create_person!(workspace, company: company, email: "client@example.com")
      suggested = create_deal!(workspace, company: company, contacts: [person], name: "Suggested opp")

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-new",
          rfc822_message_ids: [],
          participant_emails: ["client@example.com"]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["linked"]).to be_empty
      expect(body["suggestions"].map { |d| d["id"] }).to include(suggested.id)
    end

    it "does not return a deal linked to another thread" do
      deal = create_deal!(workspace, company: company, name: "Thread A opp")
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-a",
        rfc822_message_id: "<a@mail.example.com>"
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-b",
          rfc822_message_ids: ["<b@mail.example.com>"],
          participant_emails: ["other@example.com"]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["linked"].map { |d| d["name"] }).not_to include("Thread A opp")
    end

    it "does not match deals when gmail_thread_id is blank" do
      deal = create_deal!(workspace, company: company, name: "Orphan thread opp")
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: nil,
        rfc822_message_id: nil
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "",
          rfc822_message_ids: [],
          participant_emails: ["client@example.com"]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["linked"].map { |d| d["name"] }).not_to include("Orphan thread opp")
    end

    it "suggests companies that match an external email domain" do
      company.update!(domain: "ing.es", name: "ING")

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-ing",
          rfc822_message_ids: [],
          participant_emails: ["Ana <ana@ing.es>", user.email_address]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["suggested_companies"].map { |item| item["id"] }).to include(company.id)
      expect(body["suggested_companies"].first["domain"]).to eq("ing.es")
    end

    it "does not match deals when rfc822_message_ids contains blank values" do
      deal = create_deal!(workspace, company: company, name: "Blank message id opp")
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-x",
        rfc822_message_id: ""
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-y",
          rfc822_message_ids: [""],
          participant_emails: ["client@example.com"]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["linked"].map { |d| d["name"] }).not_to include("Blank message id opp")
    end

    it "does not suggest deals whose only contact is the current user" do
      person = create_person!(workspace, company: company, email: user.email_address)
      create_deal!(workspace, company: company, contacts: [person], name: "Self contact opp")

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-new",
          rfc822_message_ids: [],
          participant_emails: [user.email_address]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["suggestions"].map { |d| d["name"] }).not_to include("Self contact opp")
    end

    it "returns 401 without auth" do
      post "/api/v1/gmail/threads/status",
        params: {gmail_thread_id: "thread-abc"},
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/gmail/threads/link" do
    it "links a thread to an existing deal and dedupes messages" do
      deal = create_deal!(workspace, company: company, name: "Existing opp")
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-abc",
        rfc822_message_id: "<msg-1@mail.example.com>"
      )

      expect {
        post "/api/v1/gmail/threads/link",
          params: {deal_id: deal.id, thread: thread_payload},
          headers: headers,
          as: :json
      }.to change { deal.email_messages.count }.by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["imported_count"]).to eq(1)
      expect(body.dig("deal", "name")).to eq("Existing opp")
      expect(deal.activities.where(action: "email_linked").count).to eq(1)
    end

    it "creates a new deal and imports the full thread" do
      selected_stage = pipeline.pipeline_stages.find_by!(name: "Qualified")

      expect {
        post "/api/v1/gmail/threads/link",
          params: {
            new_deal: {name: "From Gmail thread", pipeline_stage_id: selected_stage.id, create_company: true},
            thread: thread_payload
          },
          headers: headers,
          as: :json
      }.to change(Deal, :count).by(1)
        .and change(Person, :count).by(1)
        .and change(EmailMessage, :count).by(2)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("deal", "name")).to eq("From Gmail thread")
      expect(body["imported_count"]).to eq(2)

      deal = Deal.find(body.dig("deal", "id"))
      expect(deal.pipeline_stage).to eq(selected_stage)
      expect(deal.contacts.map(&:email)).to include("client@example.com")
      expect(deal.email_messages.pluck(:gmail_message_id)).to contain_exactly("msg-1", "msg-2")
    end

    it "imports messages whose body is blank" do
      blank_thread = thread_payload.deep_dup
      blank_thread[:messages].each { |message| message[:body] = "   " }

      expect {
        post "/api/v1/gmail/threads/link",
          params: {
            new_deal: {name: "Empty body", pipeline_stage_id: pipeline.pipeline_stages.first.id, create_company: true},
            thread: blank_thread
          },
          headers: headers,
          as: :json
      }.to change(Deal, :count).by(1)

      expect(response).to have_http_status(:created)
      deal = Deal.find(JSON.parse(response.body).dig("deal", "id"))
      expect(deal.email_messages.pluck(:body)).to all(eq("(no body)"))
    end

    it "keeps html and line breaks in the imported body" do
      html_thread = thread_payload.deep_dup
      html_thread[:messages].each { |message| message[:gmail_message_id] = "#{message[:gmail_message_id]}-html" }
      html_thread[:messages].first[:body] = "<p>Hola</p>\n<p>Seguimos.</p>"

      post "/api/v1/gmail/threads/link",
        params: {
          new_deal: {name: "Html body", pipeline_stage_id: pipeline.pipeline_stages.first.id, create_company: true},
          thread: html_thread
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:created)
      deal = Deal.find(JSON.parse(response.body).dig("deal", "id"))
      expect(deal.email_messages.order(:created_at).first.body).to eq("<p>Hola</p>\n<p>Seguimos.</p>")
    end

    it "attaches an existing company when company_name matches" do
      post "/api/v1/gmail/threads/link",
        params: {
          new_deal: {
            name: "Named company",
            pipeline_stage_id: pipeline.pipeline_stages.first.id,
            company_name: "acme corp"
          },
          thread: thread_payload
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:created)
      deal = Deal.find(JSON.parse(response.body).dig("deal", "id"))
      expect(deal.company).to eq(company)
    end

    it "creates the company named in the request" do
      expect {
        post "/api/v1/gmail/threads/link",
          params: {
            new_deal: {
              name: "New company",
              pipeline_stage_id: pipeline.pipeline_stages.first.id,
              company_name: "Northwind",
              create_company: true
            },
            thread: thread_payload
          },
          headers: headers,
          as: :json
      }.to change(Company, :count).by(1)

      expect(response).to have_http_status(:created)
      deal = Deal.find(JSON.parse(response.body).dig("deal", "id"))
      expect(deal.company.name).to eq("Northwind")
      expect(deal.company.domain).to eq("example.com")
    end

    it "does not create a company until it is confirmed" do
      expect {
        post "/api/v1/gmail/threads/link",
          params: {
            new_deal: {
              name: "Needs confirmation",
              pipeline_stage_id: pipeline.pipeline_stages.first.id,
              company_name: "Northwind"
            },
            thread: thread_payload
          },
          headers: headers,
          as: :json
      }.not_to change(Company, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("Company doesn't exist")
      expect(body["domain"]).to eq("example.com")
    end

    it "stores the email domain on a company matched by name when it has none" do
      post "/api/v1/gmail/threads/link",
        params: {
          new_deal: {
            name: "Named company",
            pipeline_stage_id: pipeline.pipeline_stages.first.id,
            company_name: "Acme Corp"
          },
          thread: thread_payload
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:created)
      expect(company.reload.domain).to eq("example.com")
    end

    it "returns 404 for a deal outside the workspace" do
      foreign = create_deal!(workspaces(:two))

      post "/api/v1/gmail/threads/link",
        params: {deal_id: foreign.id, thread: thread_payload},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "OAuth authentication" do
    let(:oauth_app) do
      Doorkeeper::Application.create!(
        name: "Gmail add-on test",
        redirect_uri: "https://script.google.com/macros/d/test/usercallback",
        confidential: false,
        scopes: "api"
      )
    end

    let(:oauth_headers) do
      access_token = Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "api",
        expires_in: 2.hours
      )
      {"Authorization" => "Bearer #{access_token.plaintext_token}"}
    end

    it "accepts a doorkeeper access token with scope api" do
      post "/api/v1/gmail/threads/status",
        params: {gmail_thread_id: "thread-abc", rfc822_message_ids: [], participant_emails: []},
        headers: oauth_headers,
        as: :json

      expect(response).to have_http_status(:success)
    end

    it "rejects a doorkeeper token without scope api" do
      access_token = Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: user.id,
        scopes: "mcp",
        expires_in: 2.hours
      )

      post "/api/v1/gmail/threads/status",
        params: {gmail_thread_id: "thread-abc"},
        headers: {"Authorization" => "Bearer #{access_token.plaintext_token}"},
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "still accepts cream_ api tokens" do
      post "/api/v1/gmail/threads/status",
        params: {gmail_thread_id: "thread-abc", rfc822_message_ids: [], participant_emails: []},
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
    end

    it "lists available workspaces with their pipelines and stages" do
      get "/api/v1/gmail/context", headers: oauth_headers, as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["selected_workspace_id"]).to eq(workspace.id)
      selected = body["workspaces"].find { |item| item["id"] == workspace.id }
      expect(selected["pipelines"].first["name"]).to eq(pipeline.name)
      expect(selected["pipelines"].first["stages"].map { |stage| stage["name"] }).to include("Lead", "Won")
    end

    it "exposes the user's preferred pipeline for Gmail" do
      preferred_pipeline = pipeline.duplicate(name: "Partners").tap(&:save!)
      memberships(:one_one).update!(current_pipeline: preferred_pipeline)

      get "/api/v1/gmail/context", headers: oauth_headers, as: :json

      expect(response).to have_http_status(:success)
      workspace_context = JSON.parse(response.body)["workspaces"].find { |item| item["id"] == workspace.id }
      expect(workspace_context["default_pipeline_id"]).to eq(preferred_pipeline.id)
    end

    it "selects an OAuth workspace through the workspace header" do
      multi_workspace_user = users(:two)
      other_workspace = workspaces(:two)
      other_pipeline = Pipeline.create_default!(other_workspace)
      access_token = Doorkeeper::AccessToken.create!(
        application: oauth_app,
        resource_owner_id: multi_workspace_user.id,
        scopes: "api",
        expires_in: 2.hours
      )

      get "/api/v1/gmail/context",
        headers: {
          "Authorization" => "Bearer #{access_token.plaintext_token}",
          "X-Cream-Workspace-Id" => other_workspace.id.to_s
        },
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["selected_workspace_id"]).to eq(other_workspace.id)
      selected = body["workspaces"].find { |item| item["id"] == other_workspace.id }
      expect(selected["pipelines"].first["id"]).to eq(other_pipeline.id)
    end

    it "rejects selecting a workspace outside the OAuth user's memberships" do
      get "/api/v1/gmail/context",
        headers: oauth_headers.merge("X-Cream-Workspace-Id" => workspaces(:two).id.to_s),
        as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "does not allow an API token to switch workspaces" do
      get "/api/v1/gmail/context",
        headers: headers.merge("X-Cream-Workspace-Id" => workspaces(:two).id.to_s),
        as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
