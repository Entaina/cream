require "rails_helper"

RSpec.describe BookingCreator, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships
  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "creator-test",
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
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.find_by!(slug: "video") }
  let(:client) { instance_double(GoogleCalendar::Client) }
  let(:request) { instance_double(ActionDispatch::Request, remote_ip: "127.0.0.1", user_agent: "rspec") }

  before do
    travel_to Time.zone.parse("2026-07-28 08:00")
    allow(BookingAvailabilityService).to receive(:slot_available?).and_return(true)
    allow(client).to receive(:create_event).and_return(
      "id" => "evt1",
      "htmlLink" => "https://calendar.google.com/event/1",
      "conferenceData" => {
        "entryPoints" => [{"entryPointType" => "video", "uri" => "https://meet.google.com/abc"}]
      }
    )
  end

  it "creates booking and CRM records" do
    result = described_class.call(
      booking_page: booking_page,
      event_type: event_type,
      params: {
        datetime: "2026-07-28T10:00:00",
        timezone: "Europe/Madrid",
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        utm_source: "newsletter",
        source_page: "https://example.com/b/agenda-test?utm_source=newsletter",
        referrer: "https://google.com"
      },
      request: request,
      client: client
    )

    expect(result.booking).to be_persisted
    expect(result.booking.meet_link).to eq("https://meet.google.com/abc")
    expect(result.booking.metadata).to include(
      "booking_page_slug" => "creator-test",
      "booking_page_name" => "Agenda",
      "utm_source" => "newsletter",
      "source_page" => "https://example.com/b/agenda-test?utm_source=newsletter",
      "referrer" => "https://google.com",
      "ip" => "127.0.0.1",
      "user_agent" => "rspec"
    )
    expect(workspace.people.with_email("ana@example.com")).to exist
    expect(workspace.deals.where("name ILIKE ?", "%Ana Lopez%")).to exist
    expect(client).to have_received(:create_event)

    deal = result.booking.deal
    person = workspace.people.with_email("ana@example.com").first
    deal_activity = deal.activities.find_by!(action: "booking_created")
    person_activity = person.activities.find_by!(action: "booking_created")
    expect(deal_activity.user).to eq(user)
    expect(person_activity.user).to eq(user)
    expect(deal_activity.metadata).to include(
      "booking_id" => result.booking.id,
      "guest" => "Ana Lopez",
      "event_name" => "Online"
    )
    expect(deal_activity.metadata["starts_at"]).to be_present

    notification = user.notifications.order(:id).last
    expect(notification).to be_present
    expect(notification.kind).to eq("booking")
    expect(notification.title).to eq("New booking")
    expect(notification.body).to include("Ana Lopez")
    expect(notification.body).to include("ana@example.com")
    expect(notification.url).to eq(Rails.application.routes.url_helpers.deal_path(result.booking.deal))
  end

  it "emails the host when they enabled the email channel" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: true)

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T10:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.to have_enqueued_mail(BookingMailer, :host_notification)
      .and change(Notification, :count).by(0)
  end

  it "skips host notification when they disabled all channels" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: false)

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T10:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.to change(Notification, :count).by(0)
      .and have_enqueued_mail(BookingMailer, :host_notification).exactly(0).times
  end

  it "enqueues a reminder job one hour before the booking starts" do
    remind_at = ActiveSupport::TimeZone["Europe/Madrid"].parse("2026-07-28T11:00:00")

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T12:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.to have_enqueued_job(BookingReminderJob).at(remind_at)
  end

  it "respects a custom reminder_minutes_before value" do
    event_type.update!(reminder_minutes_before: 30)
    remind_at = ActiveSupport::TimeZone["Europe/Madrid"].parse("2026-07-28T11:30:00")

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T12:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.to have_enqueued_job(BookingReminderJob).at(remind_at)
  end

  it "does not enqueue a reminder when disabled on the event type" do
    event_type.update!(reminder_minutes_before: 0)

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T10:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.not_to have_enqueued_job(BookingReminderJob)
  end

  it "does not enqueue a reminder when the remind time is in the past" do
    event_type.update!(reminder_minutes_before: 120)

    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T09:30:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.not_to have_enqueued_job(BookingReminderJob)
  end

  it "sends a confirmation email when an email template is configured" do
    template = workspace.email_templates.create!(
      user: user,
      name: "Confirmación reserva",
      subject: "Reserva: {event_name} — {date}",
      body: "Hola {first_name}, tu reunión {event_name} es el {date} a las {time} ({timezone}). Meet: {meet_link}"
    )
    event_type.update!(email_template: template)

    I18n.with_locale(:es) do
      expect {
        result = described_class.call(
          booking_page: booking_page,
          event_type: event_type,
          params: {
            datetime: "2026-07-28T10:00:00",
            timezone: "Europe/Madrid",
            lang: "es",
            first_name: "Ana",
            last_name: "Lopez",
            email: "ana@example.com"
          },
          request: request,
          client: client
        )

        message = workspace.email_messages.order(:id).last
        expect(message).to be_present
        expect(message.to_address).to eq("ana@example.com")
        expect(message.subject).to include("Online")
        expect(message.body).to include("Ana")
        expect(message.body).to include("https://meet.google.com/abc")
        expect(message.body).to match(/julio|Julio|martes|Martes/)
        expect(message.record).to eq(result.booking.deal)
        expect(message.user).to eq(user)
      }.to have_enqueued_job(SendViaGmailJob)
    end
  end

  it "attaches email template files to the booking confirmation message" do
    template = workspace.email_templates.create!(
      user: user,
      name: "Confirmación reserva",
      subject: "Reserva confirmada",
      body: "Hola {first_name}"
    )
    template.attachments.attach(
      io: StringIO.new("ics content"),
      filename: "agenda.pdf",
      content_type: "application/pdf"
    )
    event_type.update!(email_template: template)

    described_class.call(
      booking_page: booking_page,
      event_type: event_type,
      params: {
        datetime: "2026-07-28T10:00:00",
        timezone: "Europe/Madrid",
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com"
      },
      request: request,
      client: client
    )

    message = workspace.email_messages.order(:id).last
    expect(message.attachments.count).to eq(1)
    expect(message.attachments.first.filename.to_s).to eq("agenda.pdf")
  end

  it "does not send a confirmation email without a template" do
    expect {
      described_class.call(
        booking_page: booking_page,
        event_type: event_type,
        params: {
          datetime: "2026-07-28T10:00:00",
          timezone: "Europe/Madrid",
          first_name: "Ana",
          last_name: "Lopez",
          email: "ana@example.com"
        },
        request: request,
        client: client
      )
    }.not_to have_enqueued_job(SendViaGmailJob)
  end

  it "reuses an existing deal in the target pipeline and stage" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "ana@example.com", first_name: "Ana", last_name: "Lopez")
    existing_deal = create_deal!(
      workspace,
      pipeline: pipeline,
      stage: pipeline.first_stage,
      company: company,
      contacts: [person],
      name: "Existing deal"
    )

    result = described_class.call(
      booking_page: booking_page,
      event_type: event_type,
      params: {
        datetime: "2026-07-28T11:00:00",
        timezone: "Europe/Madrid",
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com"
      },
      request: request,
      client: client
    )

    expect(result.booking.deal).to eq(existing_deal)
    expect(workspace.deals.where(pipeline: pipeline, pipeline_stage: pipeline.first_stage).count).to eq(1)
    expect(existing_deal.activities.where(action: "booking_created")).to exist
    expect(person.activities.where(action: "booking_created")).to exist
  end
end
