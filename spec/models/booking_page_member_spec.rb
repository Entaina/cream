require "rails_helper"

RSpec.describe BookingPageMember, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:host) { users(:one) }
  let(:co_host) { users(:two) }
  let(:pipeline) { Pipeline.create_default!(workspace) }
  let(:booking_page) do
    page = workspace.booking_pages.new(
      name: "Agenda", slug: "members-test", host: host, pipeline: pipeline,
      timezone: "Europe/Madrid", calendar_ids: ["host-cal"]
    )
    page.event_types.build(BookingEventType.blank_attributes.merge(slug: "call", name_i18n: {"es" => "Llamada"}))
    page.save!
    page
  end

  def connect!(user, scopes: nil)
    workspace.calendar_connections.create!(
      user: user, email: user.email_address, refresh_token: "rt", access_token: "at",
      expires_at: 1.hour.from_now, granted_scopes: scopes
    )
  end

  describe "validations" do
    it "is valid for another workspace member" do
      expect(booking_page.members.build(user: co_host)).to be_valid
    end

    it "rejects the host" do
      member = booking_page.members.build(user: host)

      expect(member).not_to be_valid
      expect(member.errors[:user]).to be_present
    end

    it "rejects users outside the workspace" do
      member = booking_page.members.build(user: users(:outsider))

      expect(member).not_to be_valid
    end

    it "rejects the same user twice" do
      booking_page.members.create!(user: co_host)

      expect(booking_page.members.build(user: co_host)).not_to be_valid
    end
  end

  describe "BookingPage co-hosts" do
    it "assigns co-hosts with co_host_ids" do
      booking_page.update!(co_host_ids: [co_host.id])

      expect(booking_page.reload.co_hosts).to contain_exactly(co_host)
    end

    it "lists the host first, each participant with only their own calendars" do
      booking_page.update!(co_host_ids: [co_host.id])
      booking_page.assign_calendar_ids_for(co_host, ["co-cal"])
      booking_page.save!

      participants = booking_page.reload.participants

      expect(participants.map(&:user)).to eq([host, co_host])
      expect(participants.map(&:calendar_ids)).to eq([["host-cal"], ["co-cal"]])
    end

    it "knows who participates" do
      booking_page.update!(co_host_ids: [co_host.id])

      expect(booking_page.participant?(host)).to be true
      expect(booking_page.participant?(co_host)).to be true
      expect(booking_page.participant?(users(:three))).to be false
    end

    it "writes calendars to the host or to the co-host without mixing them" do
      booking_page.update!(co_host_ids: [co_host.id])

      booking_page.assign_calendar_ids_for(co_host, ["co-cal", ""])
      booking_page.save!
      booking_page.reload

      expect(booking_page.calendar_ids_for(co_host)).to eq(["co-cal"])
      expect(booking_page.calendar_ids_for(host)).to eq(["host-cal"])
    end

    it "update_as saves attributes and the acting user's calendars atomically" do
      booking_page.update!(co_host_ids: [co_host.id])

      saved = booking_page.update_as(co_host, {name: "Nuevo"}, calendar_ids: ["co-cal"])

      expect(saved).to be true
      booking_page.reload
      expect(booking_page.name).to eq("Nuevo")
      expect(booking_page.calendar_ids_for(co_host)).to eq(["co-cal"])
      expect(booking_page.calendar_ids).to eq(["host-cal"])
    end

    it "update_as rolls everything back when the page is invalid" do
      booking_page.update!(co_host_ids: [co_host.id])

      saved = booking_page.update_as(co_host, {name: ""}, calendar_ids: ["co-cal"])

      expect(saved).to be false
      expect(booking_page.reload.calendar_ids_for(co_host)).to eq([])
    end

    it "is ready only when every co-host has calendars and an operational connection" do
      connect!(host)
      expect(booking_page).to be_ready_for_booking

      booking_page.update!(co_host_ids: [co_host.id])
      expect(booking_page.reload).not_to be_ready_for_booking

      booking_page.assign_calendar_ids_for(co_host, ["co-cal"])
      booking_page.save!
      expect(booking_page.reload).not_to be_ready_for_booking

      connect!(co_host)
      expect(booking_page.reload).to be_ready_for_booking
    end

    it "is not ready when the co-host connection lacks the required scopes" do
      connect!(host)
      connect!(co_host, scopes: CalendarConnection::READONLY_SCOPE)
      booking_page.update!(co_host_ids: [co_host.id])
      booking_page.assign_calendar_ids_for(co_host, ["co-cal"])
      booking_page.save!

      expect(booking_page.reload).not_to be_ready_for_booking
    end
  end
end
