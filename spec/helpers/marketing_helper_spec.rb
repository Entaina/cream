require "rails_helper"

RSpec.describe MarketingHelper, type: :helper do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  describe "#journey_step_label" do
    it "includes the step number and description" do
      journey = workspace.journeys.create!(name: "Test", entry_trigger: "manual", active: true)
      step = journey.steps.create!(position: 2, step_type: "wait", config: {"minutes" => 1440})

      expect(helper.journey_step_label(step, workspace: workspace)).to eq("3. Esperar 1 día")
    end
  end

  describe "#format_journey_wait_duration" do
    it "formats minutes only for short waits" do
      expect(helper.format_journey_wait_duration(5)).to eq("5 min")
      expect(helper.format_journey_wait_duration(45)).to eq("45 min")
    end

    it "includes hours from 60 minutes onward" do
      expect(helper.format_journey_wait_duration(60)).to eq("1 h")
      expect(helper.format_journey_wait_duration(90)).to eq("1 h 30 min")
      expect(helper.format_journey_wait_duration(120)).to eq("2 h")
    end

    it "includes days from 24 hours onward" do
      expect(helper.format_journey_wait_duration(1440)).to eq("1 día")
      expect(helper.format_journey_wait_duration(2880)).to eq("2 días")
      expect(helper.format_journey_wait_duration(1500)).to eq("1 día 1 h")
      expect(helper.format_journey_wait_duration(1441)).to eq("1 día 1 min")
    end

    it "defaults invalid values to 1 minute" do
      expect(helper.format_journey_wait_duration(0)).to eq("1 min")
      expect(helper.format_journey_wait_duration(-5)).to eq("1 min")
    end
  end
end
