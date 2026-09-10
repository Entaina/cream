require "rails_helper"

RSpec.describe Marketing::Beehiiv::SubscriberSync do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let!(:publication) { create_beehiiv_publication!(workspace) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "creates a person and newsletter subscription for active Beehiiv subscribers" do
    record = {
      "id" => "sub_11111111-1111-1111-1111-111111111111",
      "email" => "beehiiv@example.com",
      "status" => "active",
      "utm_source" => "Twitter",
      "custom_fields" => [
        { "name" => "First Name", "value" => "Ada" },
        { "name" => "Last Name", "value" => "Lovelace" }
      ]
    }

    person = described_class.apply!(publication: publication, record: record, source: "beehiiv:sync")

    expect(person.email).to eq("beehiiv@example.com")
    expect(person.first_name).to eq("Ada")
    expect(person.source).to eq("beehiiv")

    newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
    subscription = EmailSubscription.find_by!(person: person, subscription_type: newsletter)
    expect(subscription.status).to eq("subscribed")
    expect(subscription.beehiiv_subscription_id).to eq("sub_11111111-1111-1111-1111-111111111111")
    expect(subscription.metadata["utm_source"]).to eq("Twitter")
  end

  it "marks pending Beehiiv subscribers as pending in Cream" do
    person = create_person!(workspace, email: "pending@example.com")

    described_class.apply!(
      publication: publication,
      record: { "id" => "sub_pending", "email" => person.email, "status" => "pending" },
      source: "beehiiv:sync"
    )

    newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
    expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter).status).to eq("pending")
    expect(Marketing::MqlEligibility.eligible?(person)).to be(false)
  end

  it "unsubscribes and suppresses invalid Beehiiv addresses" do
    person = create_person!(workspace, email: "bounce@example.com")

    described_class.apply!(
      publication: publication,
      record: { "id" => "sub_invalid", "email" => person.email, "status" => "invalid" },
      source: "beehiiv:sync"
    )

    newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
    expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter).status).to eq("unsubscribed")
    expect(EmailSuppression.suppressed?(workspace, person.email)).to be(true)
  end
end
