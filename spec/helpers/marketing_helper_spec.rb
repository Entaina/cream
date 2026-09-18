require "rails_helper"

RSpec.describe MarketingHelper, type: :helper do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }

  describe "#journey_step_label" do
    it "includes the step number and description" do
      journey = workspace.journeys.create!(name: "Test", entry_trigger: "manual", active: true)
      step = journey.steps.create!(position: 2, step_type: "wait", config: {"minutes" => 1440})

      expect(helper.journey_step_label(step, workspace: workspace)).to eq("3. #{I18n.t("marketing.journey_steps.wait", duration: I18n.t("marketing.wait_duration.one_day"))}")
    end
  end

  describe "#format_journey_wait_duration" do
    it "formats minutes only for short waits" do
      expect(helper.format_journey_wait_duration(5)).to eq(I18n.t("marketing.wait_duration.n_minutes", count: 5))
      expect(helper.format_journey_wait_duration(45)).to eq(I18n.t("marketing.wait_duration.n_minutes", count: 45))
    end

    it "includes hours from 60 minutes onward" do
      expect(helper.format_journey_wait_duration(60)).to eq(I18n.t("marketing.wait_duration.one_hour"))
      expect(helper.format_journey_wait_duration(90)).to eq("#{I18n.t("marketing.wait_duration.one_hour")} #{I18n.t("marketing.wait_duration.n_minutes", count: 30)}")
      expect(helper.format_journey_wait_duration(120)).to eq(I18n.t("marketing.wait_duration.n_hours", count: 2))
    end

    it "includes days from 24 hours onward" do
      expect(helper.format_journey_wait_duration(1440)).to eq(I18n.t("marketing.wait_duration.one_day"))
      expect(helper.format_journey_wait_duration(2880)).to eq(I18n.t("marketing.wait_duration.n_days", count: 2))
      expect(helper.format_journey_wait_duration(1500)).to eq("#{I18n.t("marketing.wait_duration.one_day")} #{I18n.t("marketing.wait_duration.one_hour")}")
      expect(helper.format_journey_wait_duration(1441)).to eq("#{I18n.t("marketing.wait_duration.one_day")} #{I18n.t("marketing.wait_duration.one_minute")}")
    end

    it "defaults invalid values to 1 minute" do
      expect(helper.format_journey_wait_duration(0)).to eq(I18n.t("marketing.wait_duration.one_minute"))
      expect(helper.format_journey_wait_duration(-5)).to eq(I18n.t("marketing.wait_duration.one_minute"))
    end
  end
end
