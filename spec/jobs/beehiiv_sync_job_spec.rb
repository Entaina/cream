require "rails_helper"

RSpec.describe BeehiivSyncJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:publication) { create_beehiiv_publication!(workspace) }

  it "skips when sync is disabled" do
    publication.beehiiv_connection.update!(sync_enabled: false)
    client = instance_double(Marketing::Beehiiv::Client)
    allow(Marketing::Beehiiv::Client).to receive(:new).and_return(client)

    described_class.perform_now(publication.id)

    expect(Marketing::Beehiiv::Client).not_to have_received(:new)
  end

  it "syncs subscribers and updates timestamps" do
    publication.beehiiv_connection.update!(sync_enabled: true)
    client = instance_double(Marketing::Beehiiv::Client)
    allow(Marketing::Beehiiv::Client).to receive(:new).with(publication).and_return(client)
    allow(client).to receive(:list_subscriptions).and_return(
      {"data" => [{"id" => "sub-1", "email" => "sync@example.com", "status" => "active"}], "has_more" => false}
    )
    allow(Marketing::Beehiiv::SubscriberSync).to receive(:apply!)

    described_class.perform_now(publication.id)

    expect(Marketing::Beehiiv::SubscriberSync).to have_received(:apply!)
    expect(publication.reload.last_synced_at).to be_present
  end

  it "stores last_error and re-raises on failure" do
    publication.beehiiv_connection.update!(sync_enabled: true)
    client = instance_double(Marketing::Beehiiv::Client)
    allow(Marketing::Beehiiv::Client).to receive(:new).and_return(client)
    allow(client).to receive(:list_subscriptions).and_raise(StandardError, "API down")

    expect {
      described_class.perform_now(publication.id)
    }.to raise_error(StandardError, "API down")

    expect(publication.reload.last_error).to eq("API down")
  end
end
