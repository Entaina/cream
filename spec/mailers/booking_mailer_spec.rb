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

    it "attaches an ics file for the booking" do
      booking.update!(
        google_event_id: "evt1",
        meet_link: "https://meet.google.com/abc-defg-hij",
        phone: "600000000"
      )
      mail = described_class.host_notification(booking: booking, host: user)
      ics = mail.attachments["event.ics"]

      expect(ics).to be_present
      expect(ics.mime_type).to include("text/calendar")
      body = ics.body.decoded
      expect(body).to include("BEGIN:VCALENDAR", "METHOD:PUBLISH", "SUMMARY:Online — Ana Lopez")
      expect(body).to include("UID:evt1@google.com")
      expect(body).to include("ana@example.com", "600000000", "https://meet.google.com/abc-defg-hij")
      expect(body).to include("DTSTART:#{booking.starts_at.utc.strftime("%Y%m%dT%H%M%SZ")}")

      booking.update!(google_ical_uid: "custom-uid@google.com")
      stored = described_class.host_notification(booking: booking, host: user).attachments["event.ics"].body.decoded
      expect(stored).to include("UID:custom-uid@google.com")
    end
  end
end
