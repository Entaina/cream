require "rails_helper"

RSpec.describe BookingEventType, type: :model do
  it "provides blank attributes with default weekly hours" do
    attrs = described_class.blank_attributes

    expect(attrs[:duration_minutes]).to eq(30)
    expect(attrs[:weekly_hours]["monday"]).to eq([])
  end

  it "requires a localized name" do
    event = described_class.new(slug: "video", duration_minutes: 30, location_type: "google_meet", name_i18n: {})
    expect(event).not_to be_valid
    expect(event.errors[:name_i18n]).to be_present
  end
end
