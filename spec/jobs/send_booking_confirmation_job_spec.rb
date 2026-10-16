require "rails_helper"

RSpec.describe SendBookingConfirmationJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "confirmation-job",
      host: user,
      crm_association: "none",
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

  it "sends over SMTP when the host has no Gmail sending connection" do
    mail = instance_double(ActionMailer::MessageDelivery, deliver_now: true)
    allow(BookingMailer).to receive(:guest_confirmation).and_return(mail)

    expect { described_class.perform_now(booking.id, "Asunto", "<p>Hola</p>") }.not_to change(EmailMessage, :count)

    expect(BookingMailer).to have_received(:guest_confirmation)
      .with(booking: booking, subject: "Asunto", body: "<p>Hola</p>", attachment_files: [])
    expect(mail).to have_received(:deliver_now)
  end

  it "sends through the host Gmail when it can send" do
    connection = instance_double(GmailConnection, connected?: true, send_enabled?: true)
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:gmail_sync).and_return(true)
    allow_any_instance_of(Workspace).to receive(:gmail_connections)
      .and_return(double(find_by: connection))
    sender = instance_double(GmailSender, send_email: true)
    allow(GmailSender).to receive(:new).with(connection).and_return(sender)
    expect(BookingMailer).not_to receive(:guest_confirmation)

    described_class.perform_now(booking.id, "Asunto", "<p>Hola</p>")

    expect(sender).to have_received(:send_email)
      .with(hash_including(to: "ana@example.com", subject: "Asunto", attachments: []))
  end

  it "ignores bookings that no longer exist" do
    expect(BookingMailer).not_to receive(:guest_confirmation)

    described_class.perform_now(0, "Asunto", "Cuerpo")
  end
end
