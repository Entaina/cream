require "rails_helper"

RSpec.describe MarketingHelper, type: :helper do
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
