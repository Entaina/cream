require "rails_helper"

RSpec.describe Booking, type: :model do
  describe "#guest_locale" do
    it "returns metadata lang when valid" do
      booking = Booking.new(metadata: {"lang" => "en"})
      expect(booking.guest_locale).to eq("en")
    end

    it "falls back to the default locale when lang is missing or invalid" do
      expect(Booking.new(metadata: {}).guest_locale).to eq(I18n.default_locale.to_s)
      expect(Booking.new(metadata: {"lang" => "fr"}).guest_locale).to eq(I18n.default_locale.to_s)
    end
  end

  describe "guest manage token" do
    it "reports cancellable only for confirmed future bookings" do
      future = Booking.new(status: "confirmed", starts_at: 1.hour.from_now)
      past = Booking.new(status: "confirmed", starts_at: 1.hour.ago)
      cancelled = Booking.new(status: "cancelled", starts_at: 1.hour.from_now)

      expect(future.cancellable?).to be(true)
      expect(past.cancellable?).to be(false)
      expect(cancelled.cancellable?).to be(false)
    end
  end

  describe ".display_starts_at_with_zone" do
    it "formats the instant in the booking timezone with the IANA label" do
      starts_at = Time.find_zone("UTC").local(2026, 7, 28, 8, 0)
      label = described_class.display_starts_at_with_zone(
        starts_at:,
        timezone: "Europe/Madrid",
        locale: :es
      )

      expect(label).to include("10:00")
      expect(label).to include("Europe/Madrid")
    end
  end
end

RSpec.describe IanaTimeZone do
  it "canonicalizes Rails zone names to IANA identifiers" do
    expect(described_class.canonical("Madrid")).to eq("Europe/Madrid")
    expect(described_class.canonical("Europe/Madrid")).to eq("Europe/Madrid")
    expect(described_class.canonical("Not/A/Zone")).to be_nil
  end
end
