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
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  describe ".propagate_subscription_fields!" do
    it "subscribes to newsletter when the configured field is checked" do
      params = { "newsletter_opt_in" => "1" }

      described_class.propagate_subscription_fields!(
        person: person,
        workspace: workspace,
        params: params,
        request: request,
        lead_form: lead_form
      )

      type = workspace.subscription_types.find_by!(slug: "newsletter")
      expect(EmailSubscription.find_by!(person: person, subscription_type: type).status).to eq("subscribed")
    end

    it "subscribes to general via legacy marketing_consent field" do
      mql_form = create_lead_form!(workspace, user: users(:one), destination: "mql")
      params = { "marketing_consent" => "1" }

      described_class.propagate_subscription_fields!(
        person: person,
        workspace: workspace,
        params: params,
        request: request,
        lead_form: mql_form
      )

      type = workspace.subscription_types.find_by!(slug: "general")
      expect(EmailSubscription.find_by!(person: person, subscription_type: type).status).to eq("subscribed")
    end

    it "includes marketing consent text for the primary MQL subscription type" do
      mql_form = create_lead_form!(
        workspace,
        user: users(:one),
        destination: "mql",
        marketing_consent_text: "Sí, quiero novedades"
      )
      params = { "marketing_consent" => "1" }

      described_class.propagate_subscription_fields!(
        person: person,
        workspace: workspace,
        params: params,
        request: request,
        lead_form: mql_form
      )

      type = workspace.subscription_types.find_by!(slug: "general")
      subscription = EmailSubscription.find_by!(person: person, subscription_type: type)
      expect(subscription.metadata["marketing_consent_text"]).to eq("Sí, quiero novedades")
    end

    it "does nothing when marketing consent feature is disabled" do
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(false)

      expect {
        described_class.propagate_subscription_fields!(
          person: person,
          workspace: workspace,
          params: { "newsletter_opt_in" => "1" },
          request: request,
          lead_form: lead_form
        )
      }.not_to change(EmailSubscription, :count)
    end
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
