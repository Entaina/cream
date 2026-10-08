require "rails_helper"

RSpec.describe "Gmail connections", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }

  def send_only_scopes
    [
      "email",
      "profile",
      GmailConnection::SEND_SCOPE
    ].join(" ")
  end

  def send_and_metadata_scopes
    "#{send_only_scopes} #{GmailConnection::METADATA_SCOPE}"
  end

  describe "OAuth connect callback" do
    before { OmniAuth.config.test_mode = true }

    after do
      OmniAuth.config.mock_auth[:google_gmail] = nil
      OmniAuth.config.test_mode = false
    end

    it "stores Gmail tokens and send-only scopes" do
      sign_in_as(user)
      OmniAuth.config.mock_auth[:google_gmail] = OmniAuth::AuthHash.new(
        provider: "google_gmail", uid: "g1",
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "at", refresh_token: "rt", expires_at: 1.hour.from_now.to_i,
          scope: send_only_scopes
        }
      )

      get "/auth/google_gmail/callback"

      connection = workspace.gmail_connections.find_by(user: user)
      expect(connection).to be_connected
      expect(connection.can_send?).to be(true)
      expect(connection.can_read_metadata?).to be(false)
      expect(response).to redirect_to(gmail_connection_path)
    end

    it "stores metadata scope when granted" do
      sign_in_as(user)
      OmniAuth.config.mock_auth[:google_gmail] = OmniAuth::AuthHash.new(
        provider: "google_gmail", uid: "g1",
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "at", refresh_token: "rt", expires_at: 1.hour.from_now.to_i,
          scope: send_and_metadata_scopes
        }
      )

      get "/auth/google_gmail/callback"

      connection = workspace.gmail_connections.find_by(user: user)
      expect(connection.can_read_metadata?).to be(true)
      expect(connection.can_read_body?).to be(false)
    end

    it "stores readonly scope for full reply logging" do
      sign_in_as(user)
      OmniAuth.config.mock_auth[:google_gmail] = OmniAuth::AuthHash.new(
        provider: "google_gmail", uid: "g1",
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "at", refresh_token: "rt", expires_at: 1.hour.from_now.to_i,
          scope: "#{send_only_scopes} #{GmailConnection::READONLY_SCOPE}"
        }
      )

      get "/auth/google_gmail/callback", params: {gmail_mode: "full"}

      connection = workspace.gmail_connections.find_by(user: user)
      expect(connection.can_read_body?).to be(true)
      expect(connection.can_read_metadata?).to be(true)
      expect(connection.scopes).not_to include(GmailConnection::METADATA_SCOPE)
    end

    it "replaces metadata with readonly on full mode re-auth" do
      sign_in_as(user)
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "old-rt", access_token: "at",
        granted_scopes: send_and_metadata_scopes
      )
      OmniAuth.config.mock_auth[:google_gmail] = OmniAuth::AuthHash.new(
        provider: "google_gmail", uid: "g1",
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "at", refresh_token: "new-rt", expires_at: 1.hour.from_now.to_i,
          scope: "#{send_only_scopes} #{GmailConnection::READONLY_SCOPE}"
        }
      )

      get "/auth/google_gmail/callback", params: {gmail_mode: "full"}

      connection = workspace.gmail_connections.find_by(user: user)
      expect(connection.scopes).not_to include(GmailConnection::METADATA_SCOPE)
      expect(connection.scopes).to include(GmailConnection::READONLY_SCOPE)
      expect(connection.full_read_blocked_by_metadata?).to be(false)
    end
  end

  describe "with gmail_sync enabled" do
    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
      sign_in_as(user)
    end

    it "toggles send_enabled when send scope is granted" do
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at",
        granted_scopes: send_only_scopes
      )

      patch gmail_connection_path, params: {gmail_connection: {send_enabled: "1"}}

      expect(workspace.gmail_connections.find_by(user: user).send_enabled).to be(true)
    end

    it "toggles sync_enabled when metadata scope is granted" do
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at",
        granted_scopes: send_and_metadata_scopes
      )

      patch gmail_connection_path, params: {gmail_connection: {sync_enabled: "1"}}

      expect(workspace.gmail_connections.find_by(user: user).sync_enabled).to be(true)
    end

    it "does not enable sync without metadata scope" do
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at",
        granted_scopes: send_only_scopes
      )

      patch gmail_connection_path, params: {gmail_connection: {sync_enabled: "1"}}

      connection = workspace.gmail_connections.find_by(user: user)
      expect(connection.sync_enabled).to be(false)
      expect(response).to redirect_to(gmail_connection_path)
      expect(flash[:alert]).to include(I18n.t("flashes.gmail.grant_inbox_for_reply_detection"))
    end

    it "enqueues a manual sync when metadata scope is granted" do
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at",
        granted_scopes: send_and_metadata_scopes
      )

      expect {
        post sync_gmail_connection_path
      }.to have_enqueued_job(GmailSyncJob).on_queue("gmail_sync")

      expect(response).to redirect_to(gmail_connection_path)
    end

    it "does not enqueue sync without metadata scope" do
      workspace.gmail_connections.create!(
        user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at",
        granted_scopes: send_only_scopes
      )

      expect {
        post sync_gmail_connection_path
      }.not_to have_enqueued_job(GmailSyncJob)

      expect(response).to redirect_to(gmail_connection_path)
      expect(flash[:alert]).to include(I18n.t("flashes.gmail.grant_inbox_for_replies"))
    end

    it "disconnects the account" do
      workspace.gmail_connections.create!(user: user, email: "me@gmail.com", refresh_token: "rt")

      expect { delete gmail_connection_path }.to change(GmailConnection, :count).by(-1)
    end
  end
end
