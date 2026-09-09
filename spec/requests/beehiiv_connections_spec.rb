require "rails_helper"

RSpec.describe "Beehiiv connections", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:member) { users(:two) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    ActiveJob::Base.queue_adapter = :test
  end

  def connection_params(**overrides)
    {
      beehiiv_connection: {
        api_key: "beehiiv-api-key",
        publication_id: "pub_00000000-0000-0000-0000-000000000000",
        webhook_signing_secret: "whsec_testsecret",
        sync_enabled: "1"
      }.merge(overrides)
    }
  end

  describe "GET /settings/workspace" do
    it "shows the Beehiiv form without echoing stored keys" do
      workspace.create_beehiiv_connection!(
        user: admin,
        api_key: "supersecretbeehiivkey",
        publication_id: "pub_00000000-0000-0000-0000-000000000000",
        webhook_signing_secret: "whsec_supersecret"
      )
      sign_in_as(admin)

      get settings_workspace_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Beehiiv")
      expect(response.body).not_to include("supersecretbeehiivkey")
      expect(response.body).to include("/e/beehiiv/")
    end
  end

  describe "POST /beehiiv_connection" do
    it "creates the connection for admins and enqueues sync" do
      sign_in_as(admin)

      expect {
        post beehiiv_connection_path, params: connection_params
      }.to change(BeehiivConnection, :count).by(1)
        .and have_enqueued_job(BeehiivSyncJob)

      connection = workspace.reload.beehiiv_connection
      expect(connection.api_key).to eq("beehiiv-api-key")
      expect(connection.publication_id).to eq("pub_00000000-0000-0000-0000-000000000000")
      expect(connection.webhook_token).to be_present
    end

    it "is admin-only" do
      sign_in_as(member)
      patch switch_workspace_path, params: { workspace_id: workspace.id }

      expect {
        post beehiiv_connection_path, params: connection_params
      }.not_to change(BeehiivConnection, :count)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /beehiiv_connection/sync" do
    it "enqueues a sync job" do
      connection = workspace.create_beehiiv_connection!(
        user: admin,
        api_key: "beehiiv-api-key",
        publication_id: "pub_00000000-0000-0000-0000-000000000000"
      )
      sign_in_as(admin)

      expect {
        post sync_beehiiv_connection_path
      }.to have_enqueued_job(BeehiivSyncJob).with(connection.id)
    end
  end
end
