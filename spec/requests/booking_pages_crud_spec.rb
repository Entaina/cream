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

    it "rejects another user's private email template on a new event type" do
      co_host = users(:two)
      private_template = workspace.email_templates.create!(
        user: co_host, name: "Private confirm", subject: "Hi", body: "Body", shared: false
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
              email_template_id: private_template.id,
              visible: "1",
              position: 0,
              weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json,
              name_i18n: {es: "Video", en: "Video"},
              description_i18n: {es: "", en: ""}
            }
          }
        }
      }

      expect(response).to have_http_status(:not_found)
      expect(video_type.reload.email_template_id).to be_nil
    end

    it "keeps an existing private template assigned when the co-host updates the page" do
      co_host = users(:two)
      private_template = workspace.email_templates.create!(
        user: user, name: "Host private", subject: "Hi", body: "Body", shared: false
      )
      video_type.update!(email_template: private_template)
      booking_page.members.create!(user: co_host, calendar_ids: ["primary"])

      sign_in_as(co_host)
      patch switch_workspace_path, params: {workspace_id: workspace.id}
      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: "Agenda co-host",
          slug: booking_page.slug,
          host_id: user.id,
          pipeline_id: pipeline.id,
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          co_host_ids: [co_host.id],
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
              email_template_id: private_template.id,
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
      expect(video_type.reload.email_template_id).to eq(private_template.id)
      expect(booking_page.reload.name).to eq("Agenda co-host")
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

  describe "CRM association" do
    let!(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda",
        slug: "agenda-crm-mode",
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

    it "defaults to deal association" do
      expect(booking_page.crm_association).to eq("deal")
    end

    it "persists person-only association" do
      patch booking_page_path(booking_page), params: {
        booking_page: {
          name: booking_page.name,
          slug: booking_page.slug,
          host_id: user.id,
          crm_association: "person",
          pipeline_id: "",
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["primary"],
          event_types_attributes: {
            "0" => {
              id: booking_page.event_types.first.id,
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
      booking_page.reload
      expect(booking_page.crm_association).to eq("person")
      expect(booking_page.pipeline).to be_nil
    end

    it "lists pages without a pipeline and shows the CRM association form field" do
      booking_page.update!(crm_association: "none", pipeline: nil)

      get booking_pages_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("booking.pages.form.crm_association_none"))

      get edit_booking_page_path(booking_page)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(I18n.t("booking.pages.form.crm_association"))
    end
  end

  describe "co-hosts" do
    let(:co_host) { users(:three) }
    let(:other_member) do
      User.create!(name: "Other Member", email_address: "other-member@example.com", password: "password").tap do |member|
        workspace.memberships.create!(user: member, role: "salesperson")
      end
    end
    let!(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda", slug: "agenda-co-hosts", host: user, pipeline: pipeline,
        timezone: "Europe/Madrid", calendar_ids: ["host-cal"]
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

    def page_params(**overrides)
      {
        booking_page: {
          name: "Agenda",
          slug: "agenda-co-hosts",
          pipeline_id: pipeline.id,
          timezone: "Europe/Madrid",
          booking_window_days: 60,
          active: true,
          calendar_ids: ["host-cal"],
          event_types_attributes: {
            "0" => {
              id: booking_page.event_types.first.id,
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
        }.merge(overrides)
      }
    end

    it "always makes the creator the host, ignoring host_id" do
      expect {
        post booking_pages_path, params: {
          booking_page: {
            name: "Nueva", slug: "nueva-co-hosts", host_id: co_host.id, crm_association: "none",
            timezone: "Europe/Madrid", booking_window_days: 60, active: true,
            calendar_ids: ["host-cal"], co_host_ids: ["", co_host.id.to_s],
            event_types_attributes: {
              "0" => {slug: "call", name_i18n: {es: "Llamada", en: "Call"}, duration_minutes: 30,
                      location_type: "google_meet", weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS.to_json}
            }
          }
        }
      }.to change(BookingPage, :count).by(1)

      created = BookingPage.find_by!(slug: "nueva-co-hosts")
      expect(created.host).to eq(user)
      expect(created.co_hosts).to contain_exactly(co_host)
    end

    it "never lets the host or an outsider become a co-host" do
      patch booking_page_path(booking_page),
        params: page_params(co_host_ids: ["", user.id.to_s, users(:outsider).id.to_s, co_host.id.to_s])

      expect(response).to redirect_to(booking_pages_path)
      expect(booking_page.reload.co_hosts).to contain_exactly(co_host)
    end

    it "notifies only the newly added co-hosts, once" do
      memberships(:one_sales_director).update!(alert_in_app: true, alert_email: true)

      expect {
        patch booking_page_path(booking_page), params: page_params(co_host_ids: ["", co_host.id.to_s])
      }.to change { co_host.notifications.where(kind: "booking_page_invite").count }.by(1)
        .and have_enqueued_mail(BookingMailer, :co_host_invitation)

      expect {
        patch booking_page_path(booking_page), params: page_params(co_host_ids: ["", co_host.id.to_s])
      }.to change(Notification, :count).by(0)
        .and have_enqueued_mail(BookingMailer, :co_host_invitation).exactly(0).times
    end

    it "does not notify when a co-host is removed" do
      booking_page.update!(co_host_ids: [co_host.id])

      expect {
        patch booking_page_path(booking_page), params: page_params(co_host_ids: [""])
      }.to change(Notification, :count).by(0)
        .and have_enqueued_mail(BookingMailer, :co_host_invitation).exactly(0).times

      expect(booking_page.reload.co_hosts).to be_empty
    end

    context "when signed in as a co-host" do
      before do
        booking_page.update!(co_host_ids: [co_host.id])
        sign_in_as(co_host)
      end

      it "saves their own calendars without touching the host's" do
        patch booking_page_path(booking_page),
          params: page_params(calendar_ids: ["co-cal"], co_host_ids: ["", co_host.id.to_s])

        expect(response).to redirect_to(booking_pages_path)
        booking_page.reload
        expect(booking_page.calendar_ids_for(co_host)).to eq(["co-cal"])
        expect(booking_page.calendar_ids).to eq(["host-cal"])
      end

      it "can add another participant" do
        patch booking_page_path(booking_page),
          params: page_params(calendar_ids: ["co-cal"], co_host_ids: ["", co_host.id.to_s, other_member.id.to_s])

        expect(booking_page.reload.co_hosts).to contain_exactly(co_host, other_member)
      end

      it "cannot remove the host" do
        patch booking_page_path(booking_page),
          params: page_params(host_id: co_host.id, calendar_ids: ["co-cal"])

        expect(booking_page.reload.host).to eq(user)
      end

      it "can open the editor and sees the page's participants as pending without their calendars" do
        get edit_booking_page_path(booking_page)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(I18n.t("booking.pages.form.co_hosts_pending", names: co_host.name))
        expect(response.body).not_to include("host-cal")
      end
    end

    it "forbids members who are not participants from editing" do
      sign_in_as(other_member)

      patch booking_page_path(booking_page), params: page_params(name: "Hack")

      expect(booking_page.reload.name).to eq("Agenda")
    end
  end
end
