require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  include TimeZoneHelper

  describe "datetime display in user zone" do
    it "formats a UTC instant in Europe/Madrid" do
      instant = Time.find_zone("UTC").local(2026, 1, 15, 10, 30)
      formatted = nil
      Time.use_zone("Europe/Madrid") do
        formatted = l(instant, format: :default)
      end

      expect(formatted).to include("11:30")
    end

    it "formats in a fixed zone even when Time.zone is different" do
      instant = Time.find_zone("UTC").local(2026, 1, 15, 10, 30)
      formatted = nil
      Time.use_zone("America/New_York") do
        formatted = l_in_time_zone(instant, "Europe/Madrid", format: :default)
      end

      expect(formatted).to include("11:30")
    end

    it "does not shift calendar dates" do
      date = Date.new(2026, 1, 15)
      in_madrid = nil
      in_new_york = nil
      Time.use_zone("Europe/Madrid") { in_madrid = l(date, format: :short) }
      Time.use_zone("America/New_York") { in_new_york = l(date, format: :short) }

      expect(in_madrid).to eq(in_new_york)
    end
  end
end
