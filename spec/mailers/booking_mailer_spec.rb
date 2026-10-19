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

    it "links the person when the booking has no deal" do
      person = workspace.people.create!(
        first_name: "Ana", last_name: "Lopez", email: "ana@example.com",
        company: LeadForm.placeholder_company_for(workspace)
      )
      booking.update!(person: person)

      mail = described_class.host_notification(booking: booking, host: user)

      expect(mail.text_part.body.decoded).to include("/people/#{person.id}")
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

  describe "#guest_confirmation" do
    it "sends the rendered email to the guest from the host" do
      mail = described_class.guest_confirmation(booking: booking, subject: "Reserva", body: "<p>Hola Ana</p>")

      expect(mail.to).to eq(["ana@example.com"])
      expect(mail.subject).to eq("Reserva")
      expect(mail.reply_to).to eq([user.email_address])
      expect(mail.body.encoded).to include("Hola Ana")
    end
  end

  describe "#co_host_invitation" do
    let(:recipient) { users(:two) }

    it "invites the user to choose their calendars with a link to the page editor" do
      mail = described_class.co_host_invitation(booking_page: booking_page, recipient: recipient, actor: user)

      expect(mail.to).to eq([recipient.email_address])
      expect(mail.subject).to include(booking_page.name)
      expect(mail.body.encoded).to include(user.name, booking_page.name)
      expect(mail.body.encoded).to include("/booking_pages/#{booking_page.id}/edit")
    end
  end
end
