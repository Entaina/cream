require "rails_helper"

RSpec.describe BookingReminderJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "reminder-test",
      host: user,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      slug: "video",
      name_i18n: {"es" => "Online"},
      duration_minutes: 30,
      location_type: "google_meet",
      weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
      slot_increment_minutes: 15,
      min_notice_hours: 0,
      reminder_minutes_before: 60,
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 2.hours.from_now,
      ends_at: 2.hours.from_now + 30.minutes,
      timezone: "Europe/Madrid",
      meet_link: "https://meet.google.com/abc"
    )
  end

  before { travel_to Time.zone.parse("2026-07-28 08:00") }

  it "delivers a reminder email for a confirmed booking" do
    expect { described_class.perform_now(booking.id) }
      .to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["ana@example.com"])
    expect(mail.subject).to include("Online")
  end

  it "uses the guest locale stored on the booking metadata" do
    event_type.update!(name_i18n: {"es" => "Online", "en" => "Video call"})
    booking.update!(metadata: {"lang" => "en"})

    described_class.perform_now(booking.id)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.subject).to include("Video call")
    expect(mail.body.encoded).to include(I18n.t("booking.mailer.reminder.greeting", name: "Ana", locale: :en))
  end

  it "is a no-op when the booking is cancelled" do
    booking.update!(status: "cancelled")

    expect(BookingMailer).not_to receive(:reminder)
    expect { described_class.perform_now(booking.id) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end

  it "is a no-op when the booking does not exist" do
    expect { described_class.perform_now(-1) }.not_to raise_error
  end

  it "is a no-op when the booking already started" do
    travel_to booking.starts_at + 1.minute

    expect(BookingMailer).not_to receive(:reminder)
    expect { described_class.perform_now(booking.id) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end

  it "is a no-op when the booking was rescheduled after the job was enqueued" do
    original = booking.starts_at.iso8601
    booking.update!(starts_at: booking.starts_at + 1.hour, ends_at: booking.ends_at + 1.hour)

    expect(BookingMailer).not_to receive(:reminder)
    expect { described_class.perform_now(booking.id, original) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end

  it "is a no-op when reminder is disabled on the event type" do
    event_type.update!(reminder_minutes_before: 0)

    expect(BookingMailer).not_to receive(:reminder)
    expect { described_class.perform_now(booking.id) }
      .not_to change { ActionMailer::Base.deliveries.size }
  end
end
