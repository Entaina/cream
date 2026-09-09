require "rails_helper"

RSpec.describe LeadFormSubmissionProcessor, "MQL destination" do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:product) { workspace.products.create!(name: "Lead magnet", price: 0) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      pipeline: pipeline,
      destination: "mql",
      product: product
    )
  end
  let(:request) do
    instance_double(
      ActionDispatch::Request,
      user_agent: "Mozilla/5.0",
      remote_ip: "203.0.113.1",
      cookie_jar: ActiveSupport::InheritableOptions.new
    )
  end

  before do
    import_lead_form_templates!(workspace)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    SubscriptionType.ensure_defaults!(workspace)
  end

  it "creates person and submission without deal" do
    params = contacto_lead_params("marketing_consent" => "1", "_submission_key" => SecureRandom.uuid)

    expect {
      result = described_class.call(lead_form:, params:, request:)
      expect(result.deal).to be_nil
      expect(result.submission.capture_destination).to eq("mql")
    }.to change(Person, :count).by(1)
      .and change(LeadSubmission, :count).by(1)
      .and change(Deal, :count).by(0)
      .and change(Marketing::ProductInterest, :count).by(1)
      .and change(EmailSubscription, :count).by(1)
  end

  it "subscribes via the subscription type consent field key" do
    params = contacto_lead_params("marketing_consent" => "1", "_submission_key" => SecureRandom.uuid)

    described_class.call(lead_form:, params:, request:)

    general = workspace.subscription_types.find_by!(slug: "general")
    person = Person.find_by!(email: params["email"])
    expect(EmailSubscription.find_by!(person: person, subscription_type: general).status).to eq("subscribed")
  end

  it "reuses submission for duplicate submission key" do
    params = contacto_lead_params("marketing_consent" => "1", "_submission_key" => SecureRandom.uuid)

    first = described_class.call(lead_form:, params:, request:)
    second = described_class.call(lead_form:, params:, request:)

    expect(second.submission.id).to eq(first.submission.id)
    expect(LeadSubmission.count).to eq(1)
    expect(Marketing::ProductInterest.count).to eq(1)
  end

  it "rejects MQL capture without submission key" do
    params = contacto_lead_params("marketing_consent" => "1")

    expect {
      described_class.call(lead_form:, params:, request:)
    }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
