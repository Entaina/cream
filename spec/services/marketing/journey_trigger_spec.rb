require "rails_helper"

RSpec.describe Marketing::JourneyTrigger do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, email: "journey@example.com") }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:journeys).and_return(true)
  end

  describe ".config_matches?" do
    it "matches when entry_config is blank for any trigger value" do
      expect(described_class.send(:config_matches?, {}, { "lead_form_id" => 5 })).to be(true)
    end

    it "matches when entry_config specifies the same value" do
      expect(described_class.send(:config_matches?, { "lead_form_id" => "5" }, { "lead_form_id" => 5 })).to be(true)
    end

    it "rejects when entry_config specifies a different value" do
      expect(described_class.send(:config_matches?, { "lead_form_id" => "3" }, { "lead_form_id" => 5 })).to be(false)
    end
  end

  describe ".enroll!" do
    let(:journey) do
      workspace.journeys.create!(name: "Manual nurture", entry_trigger: "manual", max_reenrollments: 0, active: true).tap do |record|
        record.steps.create!(position: 0, step_type: "send_email", active: true, config: { "template_id" => 1 })
      end
    end

    it "enrolls the person in the selected journey only" do
      other = workspace.journeys.create!(name: "Other manual", entry_trigger: "manual", max_reenrollments: 0, active: true)
      other.steps.create!(position: 0, step_type: "send_email", active: true, config: { "template_id" => 1 })

      expect {
        expect(described_class.enroll!(journey: journey, person: person)).to eq(:enrolled)
      }.to change { journey.enrollments.count }.by(1)
        .and change { other.enrollments.count }.by(0)
    end

    it "blocks enrollment when an open deal stops the journey" do
      product = workspace.products.create!(name: "Curso IA", price: 100)
      journey.update!(product: product, stop_on_open_deal: true)
      pipeline = Pipeline.create_default!(workspace)
      deal = create_deal!(workspace, pipeline: pipeline, company: person.company, contacts: [ person ])
      deal.deal_products.create!(product: product, quantity: 1)

      expect(described_class.enroll!(journey: journey, person: person)).to eq(:blocked)
    end
  end

  describe ".max_reenrollments_reached?" do
    let(:journey) do
      workspace.journeys.create!(name: "Once", entry_trigger: "manual", max_reenrollments: 1, active: true)
    end

    it "blocks when enrollments reach the limit" do
      journey.enrollments.create!(
        workspace: workspace,
        person: person,
        state: "completed",
        enrolled_at: Time.current
      )

      expect(described_class.send(:max_reenrollments_reached?, journey, person)).to be(true)
    end
  end
end
