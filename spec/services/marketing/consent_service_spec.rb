require "rails_helper"

RSpec.describe Marketing::ConsentService do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "lead@example.com") }
  let(:lead_form) { create_lead_form!(workspace, user: users(:one)) }
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "127.0.0.1", user_agent: "RSpec") }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  describe ".unsubscribe!" do
    it "unsubscribes without global suppression" do
      type = workspace.subscription_types.find_by!(slug: "newsletter")
      described_class.subscribe!(person: person, subscription_type: type, source: "test", legal_basis: "consent")

      described_class.unsubscribe!(person: person, subscription_type: type)

      expect(EmailSubscription.find_by!(person: person, subscription_type: type).status).to eq("unsubscribed")
      expect(EmailSuppression.suppressed?(workspace, person.email)).to be(false)
    end
  end

  describe ".unsubscribe_all!" do
    it "suppresses the address globally" do
      type = workspace.subscription_types.find_by!(slug: "newsletter")
      described_class.subscribe!(person: person, subscription_type: type, source: "test", legal_basis: "consent")

      described_class.unsubscribe_all!(person: person)

      expect(EmailSuppression.suppressed?(workspace, person.email)).to be(true)
    end
  end
end
