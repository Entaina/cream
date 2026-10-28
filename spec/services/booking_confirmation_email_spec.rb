require "rails_helper"

RSpec.describe BookingConfirmationEmail, type: :service do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let(:template) do
    workspace.email_templates.create!(
      user: user,
      name: "Booking confirm",
      subject: "{event_name}",
      body: "{confirmation_message}|{locale}|{cancel_url}"
    )
  end
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda Host",
      slug: "confirm-email",
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
      email_template: template,
      visible: true
    )
    page.save!
    page
  end
  let(:event_type) { booking_page.event_types.first }
  let(:deal) do
    workspace.deals.create!(
      name: "Deal",
      company: LeadForm.placeholder_company_for(workspace),
      pipeline: pipeline,
      pipeline_stage: pipeline.first_stage,
      owner: user,
      tasks: [
        Task.new(
          title: "Seguimiento",
          due_on: Date.current,
          workspace: workspace,
          user: user,
          assignee: user
        )
      ]
    )
  end
  let(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      deal: deal,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 1.day.from_now,
      ends_at: 1.day.from_now + 30.minutes,
      timezone: "Europe/Madrid",
      metadata: {"lang" => "es"}
    )
  end

  describe ".tokens_for" do
    it "includes management URLs and default confirmation message" do
      tokens = described_class.tokens_for(booking)

      expect(tokens["locale"]).to eq("es")
      expect(tokens["host_name"]).to eq("Agenda Host")
      expect(tokens["cancel_url"]).to include("/b/confirm-email/cancelar/")
      expect(tokens["reschedule_url"]).to include("/b/confirm-email/reprogramar/")
      expect(tokens["confirmation_message"]).to eq(I18n.t("booking.mailer.confirmation.default_message", locale: :es))
    end

    it "uses the event type custom confirmation message for the guest locale" do
      event_type.update!(confirmation_message_i18n: {"en" => "Custom EN message"})
      booking.update!(metadata: {"lang" => "en"})

      tokens = described_class.tokens_for(booking)
      expect(tokens["confirmation_message"]).to eq("Custom EN message")
    end
  end

  describe ".call" do
    it "queues gmail delivery when a template is configured" do
      expect(SendViaGmailJob).to receive(:perform_later).once

      described_class.call(booking)
      message = workspace.email_messages.last
      expect(message.to_address).to eq("ana@example.com")
      expect(message.body).to include(booking.cancel_url)
    end

    it "escapes the guest message and keeps management links working" do
      allow(SendViaGmailJob).to receive(:perform_later)
      template.update!(body: %(<p>{guest_message}</p><a href="{cancel_url}">Cancelar</a>))
      booking.update!(message: %(<a href="https://evil.test">premio</a>))

      described_class.call(booking)

      body = workspace.email_messages.last.body
      expect(body).to include("<p>&lt;a href=&quot;https://evil.test&quot;&gt;premio&lt;/a&gt;</p>")
      expect(Nokogiri::HTML.fragment(body).at_css("a")["href"]).to eq(booking.cancel_url)
    end

    it "does nothing without an email template" do
      event_type.update!(email_template: nil)

      expect(SendViaGmailJob).not_to receive(:perform_later)
      described_class.call(booking)
    end
  end

  describe "Calendly-style template example" do
    let(:body) do
      <<~HTML
        {% if locale == "en" %}EN{% else %}ES{% endif %}
        {% if meet_link != "" %}MEET{% endif %}
        {% if phone != "" %}PHONE{% endif %}
        {confirmation_message}
      HTML
    end

    it "renders bilingual branches and optional blocks" do
      booking.update!(phone: "600", meet_link: "https://meet.google.com/x")
      event_type.update!(confirmation_message_i18n: {"es" => "Mensaje propio"})
      tpl = workspace.email_templates.create!(user: user, name: "Calendly", subject: "S", body: body)

      rendered = tpl.render_for(booking, extra_tokens: described_class.tokens_for(booking))
      expect(rendered).to include("ES", "MEET", "PHONE", "Mensaje propio")
    end
  end

  describe ".call without a deal" do
    let(:person) do
      workspace.people.create!(
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        company: LeadForm.placeholder_company_for(workspace)
      )
    end

    it "files the email on the person when the booking has one" do
      booking.update!(deal: nil, person: person)

      expect(SendViaGmailJob).to receive(:perform_later).once
      expect(SendBookingConfirmationJob).not_to receive(:perform_later)

      described_class.call(booking)
      expect(workspace.email_messages.last.record).to eq(person)
    end

    it "enqueues a record-less delivery when the booking has neither person nor deal" do
      booking.update!(deal: nil, person: nil)

      expect(SendViaGmailJob).not_to receive(:perform_later)
      expect(SendBookingConfirmationJob).to receive(:perform_later).with(booking.id, "Online", /\|es\|/)

      expect { described_class.call(booking) }.not_to change(EmailMessage, :count)
    end
  end
end
