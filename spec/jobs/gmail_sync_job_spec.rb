require "rails_helper"

RSpec.describe GmailSyncJob do
  fixtures :users, :workspaces, :memberships

  it "delegates to GmailSyncService" do
    connection = workspaces(:one).gmail_connections.create!(
      user: users(:one), email: "me@gmail.com",
      refresh_token: "rt", access_token: "at", sync_enabled: true,
      granted_scopes: GmailConnection::METADATA_SCOPE
    )
    service = instance_double(GmailSyncService, sync!: true)
    allow(GmailSyncService).to receive(:new).with(connection: connection).and_return(service)

    described_class.perform_now(connection.id)

    expect(service).to have_received(:sync!)
  end
end
