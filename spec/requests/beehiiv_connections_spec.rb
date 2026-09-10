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
    SubscriptionType.ensure_defaults!(workspace)
  end

  def connection_params(**overrides)
    {
      beehiiv_connection: {
        api_key: "beehiiv-api-key",
        sync_enabled: "1"
      }.merge(overrides)
    }
  end

  def publication_params(**overrides)
    {
      beehiiv_publication: {
        subscription_type_id: workspace.subscription_types.find_by!(slug: "newsletter").id,
        publication_id: "pub_00000000-0000-0000-0000-000000000000",
        webhook_signing_secret: "whsec_testsecret"
      }.merge(overrides)
    }
  end

  describe "GET /settings/workspace" do
    it "shows the Beehiiv form without echoing stored keys" do
      create_beehiiv_publication!(
        workspace,
        user: admin,
        api_key: "supersecretbeehiivkey",
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
    it "creates the connection for admins" do
      sign_in_as(admin)

      expect {
        post beehiiv_connection_path, params: connection_params
      }.to change(BeehiivConnection, :count).by(1)

      connection = workspace.reload.beehiiv_connection
      expect(connection.api_key).to eq("beehiiv-api-key")
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

  describe "POST /beehiiv_publications" do
    it "creates a publication mapping and enqueues sync" do
      workspace.create_beehiiv_connection!(user: admin, api_key: "beehiiv-api-key")
      sign_in_as(admin)

      expect {
        post beehiiv_publications_path, params: publication_params
      }.to change(BeehiivPublication, :count).by(1)
        .and have_enqueued_job(BeehiivSyncJob)

      publication = workspace.beehiiv_connection.beehiiv_publications.last
      expect(publication.publication_id).to eq("pub_00000000-0000-0000-0000-000000000000")
      expect(publication.webhook_token).to be_present
    end
  end

  describe "POST /beehiiv_connection/sync" do
    it "enqueues a sync job per publication" do
      publication = create_beehiiv_publication!(workspace, user: admin)
      sign_in_as(admin)

      expect {
        post sync_beehiiv_connection_path
      }.to have_enqueued_job(BeehiivSyncJob).with(publication.id)
    end
  end
end
