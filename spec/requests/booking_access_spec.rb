require "rails_helper"

RSpec.describe "Booking access", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:host) { users(:three) }
  let(:other_member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
  let!(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda privada",
      slug: "acceso-reservas",
      host: host,
      pipeline: pipeline,
      timezone: "Europe/Madrid",
      calendar_ids: ["primary"]
    )
    page.event_types.build(
      BookingEventType.blank_attributes.merge(slug: "video", name_i18n: {"es" => "Video"})
    )
    page.save!
    page
  end
  let!(:booking) do
    Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: booking_page.event_types.find_by!(slug: "video"),
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: 2.days.from_now,
      ends_at: 2.days.from_now + 30.minutes,
      timezone: "Europe/Madrid"
    )
  end

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:calendar_booking).and_return(true)
  end

  context "when signed in as another member" do
    before { sign_in_as(other_member) }

    it "lists the page without edit or delete actions" do
      get booking_pages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Agenda privada")
      expect(response.body).not_to include(edit_booking_page_path(booking_page))
    end

    it "refuses to edit the page" do
      get edit_booking_page_path(booking_page)

      expect(response).to redirect_to(root_path)
    end

    it "does not list the host's bookings" do
      get bookings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Ana Lopez")
    end

    it "does not cancel the host's booking" do
      patch cancel_booking_path(booking)

      expect(response).to have_http_status(:not_found)
      expect(booking.reload.status).to eq("confirmed")
    end
  end

  context "when signed in as the host" do
    before { sign_in_as(host) }

    it "lists the page with the edit action and shows the booking" do
      get booking_pages_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(edit_booking_page_path(booking_page))

      get bookings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ana Lopez")
    end
  end
end
