require "rails_helper"

RSpec.describe Marketing::ConsentService, "Beehiiv push" do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "lead@example.com") }
  let!(:publication) { create_beehiiv_publication!(workspace) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    ActiveJob::Base.queue_adapter = :test
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "enqueues Beehiiv push when subscribing to newsletter from CRM" do
    type = workspace.subscription_types.find_by!(slug: "newsletter")

    expect {
      described_class.subscribe!(person: person, subscription_type: type, source: "crm_admin", legal_basis: "consent")
    }.to have_enqueued_job(BeehiivPushJob).with(publication.id, person.id, "subscribe", {"reactivate" => false})
  end

  it "does not enqueue Beehiiv push for inbound Beehiiv sync" do
    type = workspace.subscription_types.find_by!(slug: "newsletter")

    expect {
      described_class.subscribe!(person: person, subscription_type: type, source: "beehiiv:sync", legal_basis: "consent")
    }.not_to have_enqueued_job(BeehiivPushJob)
  end

  it "enqueues Beehiiv unsubscribe on unsubscribe_all" do
    type = workspace.subscription_types.find_by!(slug: "newsletter")
    described_class.subscribe!(person: person, subscription_type: type, source: "test", legal_basis: "consent")

    expect {
      described_class.unsubscribe_all!(person: person)
    }.to have_enqueued_job(BeehiivPushJob).with(publication.id, person.id, "unsubscribe")
  end
end
