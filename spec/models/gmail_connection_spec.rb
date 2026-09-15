require "rails_helper"

RSpec.describe GmailConnection do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  def build_connection(**attrs)
    workspace.gmail_connections.create!(
      {user: user, email: "me@gmail.com", refresh_token: "rt", access_token: "at"}.merge(attrs)
    )
  end

  describe "#can_send?" do
    it "returns true for legacy connections without granted_scopes" do
      expect(build_connection(granted_scopes: nil).can_send?).to be(true)
    end

    it "returns true when send scope is granted" do
      connection = build_connection(granted_scopes: described_class::SEND_SCOPE)
      expect(connection.can_send?).to be(true)
    end

    it "returns false when send scope is missing" do
      connection = build_connection(granted_scopes: described_class::METADATA_SCOPE)
      expect(connection.can_send?).to be(false)
    end
  end

  describe "#can_read_metadata?" do
    it "returns false for legacy connections without granted_scopes" do
      expect(build_connection(granted_scopes: nil).can_read_metadata?).to be(false)
    end

    it "returns true when metadata scope is granted" do
      connection = build_connection(granted_scopes: described_class::METADATA_SCOPE)
      expect(connection.can_read_metadata?).to be(true)
    end

    it "returns true when readonly scope is granted" do
      connection = build_connection(granted_scopes: described_class::READONLY_SCOPE)
      expect(connection.can_read_metadata?).to be(true)
    end
  end

  describe "#can_read_body?" do
    it "returns true when readonly scope is granted" do
      connection = build_connection(granted_scopes: described_class::READONLY_SCOPE)
      expect(connection.can_read_body?).to be(true)
    end

    it "returns false when only metadata scope is granted" do
      connection = build_connection(granted_scopes: described_class::METADATA_SCOPE)
      expect(connection.can_read_body?).to be(false)
    end
  end

  describe "#send_receive_full_mode?" do
    it "returns true when send and readonly scopes are granted" do
      connection = build_connection(
        granted_scopes: "#{described_class::SEND_SCOPE} #{described_class::READONLY_SCOPE}"
      )
      expect(connection.send_receive_full_mode?).to be(true)
    end
  end

  describe "#assign_oauth_credentials" do
    it "merges granted scopes on re-auth" do
      connection = build_connection(granted_scopes: described_class::SEND_SCOPE)
      auth = OmniAuth::AuthHash.new(
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "new-at",
          refresh_token: "new-rt",
          expires_at: 1.hour.from_now.to_i,
          scope: described_class::METADATA_SCOPE
        }
      )

      connection.assign_oauth_credentials(auth)

      expect(connection.scopes).to contain_exactly(
        described_class::SEND_SCOPE,
        described_class::METADATA_SCOPE
      )
    end

    it "replaces gmail scopes on full mode re-auth" do
      connection = build_connection(
        granted_scopes: "#{described_class::SEND_SCOPE} #{described_class::METADATA_SCOPE}"
      )
      auth = OmniAuth::AuthHash.new(
        info: OmniAuth::AuthHash::InfoHash.new(email: "me@gmail.com"),
        credentials: {
          token: "new-at",
          refresh_token: "new-rt",
          expires_at: 1.hour.from_now.to_i,
          scope: "#{described_class::SEND_SCOPE} #{described_class::READONLY_SCOPE}"
        }
      )

      connection.assign_oauth_credentials(auth, mode: "full")

      expect(connection.scopes).to contain_exactly(
        described_class::SEND_SCOPE,
        described_class::READONLY_SCOPE
      )
      expect(connection.full_read_blocked_by_metadata?).to be(false)
    end
  end

  describe "#full_read_blocked_by_metadata?" do
    it "returns true when metadata and readonly are both granted" do
      connection = build_connection(
        granted_scopes: "#{described_class::METADATA_SCOPE} #{described_class::READONLY_SCOPE}"
      )

      expect(connection.full_read_blocked_by_metadata?).to be(true)
    end
  end
end
