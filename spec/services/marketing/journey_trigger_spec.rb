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
