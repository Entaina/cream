require "rails_helper"

RSpec.describe BeehiivSyncSchedulerJob, type: :job do
  fixtures :users, :workspaces, :memberships

  before { ActiveJob::Base.queue_adapter = :test }

  it "enqueues sync jobs for enabled connections" do
    publication = create_beehiiv_publication!(workspaces(:one))
    publication.beehiiv_connection.update!(sync_enabled: true)

    expect {
      described_class.perform_now
    }.to have_enqueued_job(BeehiivSyncJob).with(publication.id)
  end
end
