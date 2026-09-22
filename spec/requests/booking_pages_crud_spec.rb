require "rails_helper"

RSpec.describe "Booking pages CRUD", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
    sign_in_as(user)
  end

  describe "GET /booking_pages" do
    let!(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda",
        slug: "agenda-crud-test",
        host: user,
        pipeline: pipeline,
        timezone: "Europe/Madrid",
        calendar_ids: ["primary"]
      )
      page.event_types.build(
        slug: "video",
        name_i18n: {"es" => "Video", "en" => "Video"},
        duration_minutes: 30,
        location_type: "google_meet",
        weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
        slot_increment_minutes: 15,
        min_notice_hours: 0,
        visible: true,
        position: 0
      )
      page.save!
      page
    end

    it "lists direct event type URLs" do
      get booking_pages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("booking.pages.index.direct_type_urls"))
      expect(response.body).to include("/b/#{booking_page.slug}/video")
    end

    it "renders in English when the user locale is en" do
      user.update!(locale: "en")
      get booking_pages_path
      expect(response.body).to include(I18n.t("booking.pages.index.direct_type_urls", locale: :en))
      expect(response.body).not_to include(I18n.t("booking.pages.index.direct_type_urls", locale: :es))
    ensure
      user.update!(locale: "es")
    end
  end

  describe "GET /booking_pages/:id/edit" do
    let!(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda",
        slug: "agenda-crud-test",
        host: user,
        pipeline: pipeline,
        timezone: "Europe/Madrid",
        calendar_ids: ["primary"]
      )
      page.event_types.build(
        slug: "video",
        name_i18n: {"es" => "Video", "en" => "Video"},
        duration_minutes: 30,
        location_type: "google_meet",
        weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
        slot_increment_minutes: 15,
        min_notice_hours: 0,
        visible: true,
        position: 0
      )
      page.save!
      page
    end

    it "shows direct event type URL in the form" do
      get edit_booking_page_path(booking_page)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("booking.pages.event_type.direct_url"))
      expect(response.body).to include("/b/#{booking_page.slug}/video")
    end
  end

  describe "PATCH /booking_pages/:id" do
    let!(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda",
        slug: "agenda-crud-test",
        host: user,
        pipeline: pipeline,
        timezone: "Europe/Madrid",
        calendar_ids: ["primary"]
      )
      page.event_types.build(
        slug: "video",
        name_i18n: {"es" => "Video", "en" => "Video"},
        duration_minutes: 30,
        location_type: "google_meet",
        weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
        slot_increment_minutes: 15,
        min_notice_hours: 0,
        visible: true,
        position: 0
      )
      page.save!
      page
    end
    let!(:video_type) { booking_page.event_types.find_by!(slug: "video") }
    let!(:reunion_type) do
      booking_page.event_types.create!(
        slug: "reunion",
        name_i18n: {"es" => "Reunión", "en" => "Meeting"},
        duration_minutes: 60,
        location_type: "physical",
        weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
        slot_increment_minutes: 15,
        min_notice_hours: 0,
        visible: true,
        position: 1
      )
    end

    it "adds and removes event types" do
      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: booking_page.name,
          slug: booking_page.slug,
          host_id: user.id,
          pipeline_id: pipeline.id,
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          event_types_attributes: {
            "0" => {
              id: video_type.id,
              slug: "video",
              duration_minutes: 30,
              location_type: "google_meet",
              color: "hoki",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 0,
              visible: "1",
              position: 0,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Video", en: "Video"},
              description_i18n: {es: "", en: ""},
              _destroy: "1"
            },
            "1" => {
              id: reunion_type.id,
              slug: "reunion",
              duration_minutes: 60,
              location_type: "physical",
              color: "golden",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 0,
              visible: "1",
              position: 1,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Reunión", en: "Meeting"},
              description_i18n: {es: "", en: ""}
            },
            "2" => {
              slug: "consultoria",
              duration_minutes: 45,
              location_type: "google_meet",
              color: "blue",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 4,
              visible: "1",
              position: 2,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Consultoría", en: "Consulting"},
              description_i18n: {es: "Sesión de consultoría.", en: "Consulting session."}
            }
          }
        }
      }

      expect(response).to redirect_to(booking_pages_path)
      booking_page.reload
      slugs = booking_page.event_types.order(:position).pluck(:slug)
      expect(slugs).to eq(["reunion", "consultoria"])
    end

    it "persists custom weekly hours" do
      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: booking_page.name,
          slug: booking_page.slug,
          host_id: user.id,
          pipeline_id: pipeline.id,
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          event_types_attributes: {
            "0" => {
              id: video_type.id,
              slug: "video",
              duration_minutes: 30,
              location_type: "google_meet",
              color: "hoki",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 0,
              visible: "1",
              position: 0,
              weekly_hours: {
                monday: [["09:00", "12:00"]],
                tuesday: [],
                wednesday: [],
                thursday: [],
                friday: [],
                saturday: [],
                sunday: []
              }.to_json,
              name_i18n: {es: "Video", en: "Video"},
              description_i18n: {es: "", en: ""}
            }
          }
        }
      }

      expect(response).to redirect_to(booking_pages_path)
      expect(video_type.reload.weekly_hours["monday"]).to eq([["09:00", "12:00"]])
      expect(video_type.weekly_hours["tuesday"]).to eq([])
    end

    it "persists email_template_id on event types" do
      template = workspace.email_templates.create!(
        user: user,
        name: "Confirmación reserva",
        subject: "Reserva confirmada",
        body: "Hola {first_name}"
      )

      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: booking_page.name,
          slug: booking_page.slug,
          host_id: user.id,
          pipeline_id: pipeline.id,
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          event_types_attributes: {
            "0" => {
              id: video_type.id,
              slug: "video",
              duration_minutes: 30,
              location_type: "google_meet",
              color: "hoki",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 0,
              email_template_id: template.id,
              visible: "1",
              position: 0,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Video", en: "Video"},
              description_i18n: {es: "", en: ""}
            }
          }
        }
      }

      expect(response).to redirect_to(booking_pages_path)
      expect(video_type.reload.email_template_id).to eq(template.id)
    end

    it "persists reuse_existing_deal" do
      expect(booking_page.reuse_existing_deal).to be(true)

      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: booking_page.name,
          slug: booking_page.slug,
          host_id: user.id,
          pipeline_id: pipeline.id,
          reuse_existing_deal: "0",
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          event_types_attributes: {
            "0" => {
              id: video_type.id,
              slug: "video",
              duration_minutes: 30,
              location_type: "google_meet",
              color: "hoki",
              slot_increment_minutes: 15,
              buffer_before_minutes: 0,
              buffer_after_minutes: 0,
              min_notice_hours: 0,
              visible: "1",
              position: 0,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Video", en: "Video"},
              description_i18n: {es: "", en: ""}
            }
          }
        }
      }

      expect(response).to redirect_to(booking_pages_path)
      expect(booking_page.reload.reuse_existing_deal).to be(false)
    end
  end
end
