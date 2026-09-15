require "rails_helper"

RSpec.describe "Stripe connections", type: :request do
  include ActiveJob::TestHelper

  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) } # admin of workspace one
  let(:workspace) { workspaces(:one) }
  # users(:two) is admin elsewhere and fixture ids don't order workspaces
  # predictably, so build a member whose only workspace is this one.
  let(:member) do
    User.create!(name: "Member", email_address: "member@example.com", password: "password").tap do |u|
      workspace.memberships.create!(user: u, role: "salesperson")
    end
  end

  before do
    allow(StripeClient).to receive(:new).and_return(instance_double(StripeClient, verify!: true))
  end

  describe "GET /stripe_connection" do
    it "renders the settings page without echoing the stored key" do
      workspace.stripe_connections.create!(user: admin, api_key: "rk_live_supersecret1234")
      sign_in_as(admin)

      get stripe_connection_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("rk_live_supersecret1234")
      expect(response.body).to include("1234") # masked tail
    end
  end

  describe "POST /stripe_connection" do
    it "creates the connection with a verified key and starts the first import" do
      sign_in_as(admin)

      expect {
        post stripe_connection_path, params: {stripe_connection: {api_key: "rk_test_abc", account_label: "Main"}}
      }.to have_enqueued_job(StripeSyncJob)

      expect(response).to redirect_to(stripe_connection_path)
      connection = workspace.stripe_connections.sole
      expect(connection.api_key).to eq("rk_test_abc")
      expect(connection.user).to eq(admin)
    end

    it "rejects a key Stripe refuses" do
      allow(StripeClient).to receive(:new)
        .and_return(instance_double(StripeClient).tap { |c| allow(c).to receive(:verify!).and_raise(StripeClient::AuthenticationError) })
      sign_in_as(admin)

      post stripe_connection_path, params: {stripe_connection: {api_key: "rk_test_bad"}}

      expect(response).to have_http_status(:unprocessable_entity)
      expect(workspace.stripe_connections.count).to eq(0)
    end

    it "is admin-only" do
      sign_in_as(member)

      post stripe_connection_path, params: {stripe_connection: {api_key: "rk_test_abc"}}

      expect(response).to redirect_to(root_path)
      expect(workspace.stripe_connections.count).to eq(0)
    end
  end

  describe "PATCH /stripe_connection" do
    it "keeps the stored key when the field comes back blank" do
      workspace.stripe_connections.create!(user: admin, api_key: "rk_test_abc")
      sign_in_as(admin)

      patch stripe_connection_path, params: {stripe_connection: {api_key: "", sync_enabled: "1"}}

      connection = workspace.stripe_connections.sole
      expect(connection.api_key).to eq("rk_test_abc")
      expect(connection.sync_enabled).to be(true)
    end
  end

  describe "POST /stripe_connection/sync" do
    it "enqueues a sync job" do
      connection = workspace.stripe_connections.create!(user: admin, api_key: "rk_test_abc")
      sign_in_as(admin)

      expect {
        post sync_stripe_connection_path
      }.to have_enqueued_job(StripeSyncJob).with(connection.id)
    end
  end

  describe "DELETE /stripe_connection" do
    it "removes the connection and its payments" do
      connection = workspace.stripe_connections.create!(user: admin, api_key: "rk_test_abc")
      connection.stripe_payments.create!(workspace: workspace, stripe_charge_id: "ch_1",
        amount_cents: 100, paid_at: Time.current)
      sign_in_as(admin)

      delete stripe_connection_path

      expect(workspace.stripe_connections.count).to eq(0)
      expect(workspace.stripe_payments.count).to eq(0)
    end
  end
end
