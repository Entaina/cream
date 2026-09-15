require "rails_helper"

RSpec.describe Marketing::Beehiiv::PushService do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "lead@example.com") }
  let(:publication) { create_beehiiv_publication!(workspace) }
  let(:subscription_type) { workspace.subscription_types.find_by!(slug: "newsletter") }
  let(:client) { instance_double(Marketing::Beehiiv::Client) }
  let(:service) { described_class.new(publication) }

  before do
    SubscriptionType.ensure_defaults!(workspace)
    allow(Marketing::Beehiiv::Client).to receive(:new).with(publication).and_return(client)
  end

  describe "#subscribe!" do
    it "skips create_subscription when beehiiv_subscription_id is already stored" do
      subscription = EmailSubscription.create!(
        workspace: workspace,
        person: person,
        subscription_type: subscription_type,
        status: "subscribed",
        beehiiv_subscription_id: "sub_existing",
        source: "test"
      )

      expect(client).not_to receive(:create_subscription)
      expect(client).not_to receive(:find_subscription_by_email)

      service.subscribe!(person: person)

      expect(subscription.reload.beehiiv_subscription_id).to eq("sub_existing")
      expect(subscription.metadata["beehiiv_publication_id"]).to eq(publication.publication_id)
    end

    it "persists remote id from find_subscription_by_email without creating" do
      allow(client).to receive(:find_subscription_by_email).with(person.email).and_return("id" => "sub_remote")
      expect(client).not_to receive(:create_subscription)

      subscription = EmailSubscription.create!(
        workspace: workspace,
        person: person,
        subscription_type: subscription_type,
        status: "subscribed",
        source: "test"
      )

      service.subscribe!(person: person)

      expect(subscription.reload.beehiiv_subscription_id).to eq("sub_remote")
      expect(subscription.metadata["beehiiv_subscription_id"]).to eq("sub_remote")
    end

    it "creates subscription in beehiiv when no local or remote id exists" do
      allow(client).to receive(:find_subscription_by_email).with(person.email).and_return(nil)
      allow(client).to receive(:create_subscription).with(
        email: person.email,
        reactivate_existing: false
      ).and_return("data" => {"id" => "sub_new"})

      subscription = EmailSubscription.create!(
        workspace: workspace,
        person: person,
        subscription_type: subscription_type,
        status: "subscribed",
        source: "test"
      )

      service.subscribe!(person: person)

      expect(subscription.reload.beehiiv_subscription_id).to eq("sub_new")
      expect(subscription.metadata["beehiiv_pushed_at"]).to be_present
    end

    it "calls create_subscription with reactivate even when an id already exists" do
      EmailSubscription.create!(
        workspace: workspace,
        person: person,
        subscription_type: subscription_type,
        status: "subscribed",
        beehiiv_subscription_id: "sub_existing",
        source: "test"
      )

      expect(client).to receive(:create_subscription).with(
        email: person.email,
        reactivate_existing: true
      ).and_return("data" => {"id" => "sub_reactivated"})
      expect(client).not_to receive(:find_subscription_by_email)

      service.subscribe!(person: person, reactivate: true)
    end
  end
end
