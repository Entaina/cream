require "rails_helper"

RSpec.describe GmailSyncSchedulerJob do
  fixtures :users, :workspaces, :memberships

  include ActiveJob::TestHelper

  it "enqueues sync jobs for enabled connections with metadata scope" do
    workspaces(:one).gmail_connections.create!(
      user: users(:one), email: "me@gmail.com", refresh_token: "rt", sync_enabled: true,
      granted_scopes: GmailConnection::METADATA_SCOPE
    )
    workspaces(:one).gmail_connections.create!(
      user: users(:two), email: "other@gmail.com", refresh_token: "rt2", sync_enabled: true,
      granted_scopes: GmailConnection::SEND_SCOPE
    )

    expect {
      described_class.perform_now
    }.to have_enqueued_job(GmailSyncJob).on_queue("gmail_sync").once
  end
end
