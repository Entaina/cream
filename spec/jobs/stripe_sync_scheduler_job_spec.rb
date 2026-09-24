require "rails_helper"

RSpec.describe StripeSyncSchedulerJob, type: :job do
  fixtures :users, :workspaces, :memberships

  before { ActiveJob::Base.queue_adapter = :test }

  it "enqueues sync jobs for enabled stripe connections" do
    connection = workspaces(:one).stripe_connections.create!(
      user: users(:one),
      api_key: "sk_test_abc1234567890",
      sync_enabled: true
    )

    expect {
      described_class.perform_now
    }.to have_enqueued_job(StripeSyncJob).with(connection.id)
  end
end
