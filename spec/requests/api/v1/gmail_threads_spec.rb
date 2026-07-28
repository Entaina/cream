require "rails_helper"

RSpec.describe "Api::V1::GmailThreads", type: :request do
  fixtures :users, :workspaces, :memberships, :companies

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:company) { companies(:acme) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { { "Authorization" => "Bearer #{token.plaintext_token}" } }

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
      deal = create_deal!(workspace, company: company, name: "Linked opp")
      workspace.email_messages.create!(
        user: user, record: deal, direction: "inbound", status: "received",
        from_address: "client@example.com", to_address: user.email_address,
        subject: "Proposal", body: "Hi", gmail_thread_id: "thread-abc",
        rfc822_message_id: "<msg-1@mail.example.com>"
      )

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-abc",
          rfc822_message_ids: [ "<msg-1@mail.example.com>" ],
          participant_emails: [ "client@example.com", user.email_address ]
        },
        headers: headers,
        as: :json

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["linked"].map { |d| d["name"] }).to include("Linked opp")
    end

    it "suggests deals whose contacts match thread participants" do
      person = create_person!(workspace, company: company, email: "client@example.com")
      suggested = create_deal!(workspace, company: company, contacts: [ person ], name: "Suggested opp")

      post "/api/v1/gmail/threads/status",
        params: {
          gmail_thread_id: "thread-new",
          rfc822_message_ids: [],
          participant_emails: [ "client@example.com" ]
        },
        headers: headers,
        as: :json

      body = JSON.parse(response.body)
      expect(body["linked"]).to be_empty
      expect(body["suggestions"].map { |d| d["id"] }).to include(suggested.id)
    end

    it "returns 401 without auth" do
      post "/api/v1/gmail/threads/status",
        params: { gmail_thread_id: "thread-abc" },
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
          params: { deal_id: deal.id, thread: thread_payload },
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
            new_deal: { name: "From Gmail thread", pipeline_stage_id: selected_stage.id },
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

    it "returns 404 for a deal outside the workspace" do
      foreign = create_deal!(workspaces(:two))

      post "/api/v1/gmail/threads/link",
        params: { deal_id: foreign.id, thread: thread_payload },
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
      { "Authorization" => "Bearer #{access_token.plaintext_token}" }
    end

    it "accepts a doorkeeper access token with scope api" do
      post "/api/v1/gmail/threads/status",
        params: { gmail_thread_id: "thread-abc", rfc822_message_ids: [], participant_emails: [] },
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
        params: { gmail_thread_id: "thread-abc" },
        headers: { "Authorization" => "Bearer #{access_token.plaintext_token}" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "still accepts cream_ api tokens" do
      post "/api/v1/gmail/threads/status",
        params: { gmail_thread_id: "thread-abc", rfc822_message_ids: [], participant_emails: [] },
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
