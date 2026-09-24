require "rails_helper"

RSpec.describe BookingMailer, type: :mailer do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda", slug: "mailer-test", host: user, pipeline: pipeline,
      timezone: "Europe/Madrid", calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Online"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      visible: true
    )
    page.save!
    page
  end
  let(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: booking_page.event_types.first,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 30.minutes,
      timezone: "Europe/Madrid"
    )
  end

  describe "#reminder" do
    it "sends to the guest with event name in subject" do
      mail = described_class.reminder(booking)

      expect(mail.to).to eq(["ana@example.com"])
      expect(mail.subject).to include("Online")
    end
  end

  describe "#host_notification" do
    it "notifies the host" do
      mail = described_class.host_notification(booking: booking, host: user)

      expect(mail.to).to eq([user.email_address])
      expect(mail.subject).to include("Ana")
    end
  end
end
