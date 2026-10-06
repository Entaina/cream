require "rails_helper"

RSpec.describe Person, type: :model do
  fixtures :workspaces, :users

  let(:workspace) { workspaces(:one) }

  it "requires a company" do
    person = workspace.people.new(first_name: "Pat")
    expect(person).not_to be_valid
    expect(person.errors[:company]).to be_present
  end

  it "is valid with a company" do
    person = workspace.people.new(first_name: "Pat", company: create_company!(workspace))
    expect(person).to be_valid
  end

  it "requires brought_by when source is team_member" do
    person = workspace.people.new(
      first_name: "Pat",
      company: create_company!(workspace),
      source: "team_member"
    )
    expect(person).not_to be_valid
    expect(person.errors[:brought_by_id]).to be_present
  end

  it "defaults first_contact_on to today on create" do
    person = workspace.people.create!(
      first_name: "Pat",
      company: create_company!(workspace)
    )
    expect(person.first_contact_on).to eq(Date.current)
  end

  it "does not override an explicit first_contact_on on create" do
    person = workspace.people.create!(
      first_name: "Pat",
      company: create_company!(workspace),
      first_contact_on: Date.new(2025, 3, 15)
    )
    expect(person.first_contact_on).to eq(Date.new(2025, 3, 15))
  end

  it "clears brought_by when source is not team_member" do
    person = workspace.people.new(
      first_name: "Pat",
      company: create_company!(workspace),
      source: "web_form",
      brought_by_id: users(:two).id
    )
    person.valid?
    expect(person.brought_by_id).to be_nil
  end

  describe "#destroy" do
    let(:member) { users(:one) }
    let(:lead_form) { create_lead_form!(workspace, user: member) }

    it "destroys associated lead_submissions" do
      person = create_person!(workspace, email: "lead@example.com")
      submission = workspace.lead_submissions.create!(
        lead_form: lead_form,
        person: person,
        capture_destination: "mql",
        data: {"email" => person.email},
        metadata: {"gdpr_consent_at" => Time.current.iso8601}
      )

      expect { person.destroy }.to change(LeadSubmission, :count).by(-1)
      expect(LeadSubmission.exists?(submission.id)).to be(false)
    end

    it "nullifies bookings person_id while keeping the booking" do
      pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
      booking_page = workspace.booking_pages.new(
        name: "Agenda",
        slug: "person-destroy-#{SecureRandom.hex(3)}",
        host: member,
        pipeline: pipeline,
        timezone: "Europe/Madrid",
        calendar_ids: ["primary@gmail.com"]
      )
      booking_page.event_types.build(
        slug: "video",
        name_i18n: {"es" => "Online"},
        duration_minutes: 30,
        location_type: "google_meet",
        weekly_hours: BookingEventType::DEFAULT_WEEKLY_HOURS,
        slot_increment_minutes: 15,
        min_notice_hours: 0,
        visible: true
      )
      booking_page.save!
      event_type = booking_page.event_types.find_by!(slug: "video")
      person = create_person!(workspace, email: "booker@example.com")
      booking = Booking.create!(
        workspace: workspace,
        booking_page: booking_page,
        booking_event_type: event_type,
        person: person,
        first_name: "Ana",
        last_name: "Lopez",
        email: "ana@example.com",
        starts_at: Time.zone.parse("2026-08-10 10:00"),
        ends_at: Time.zone.parse("2026-08-10 10:30"),
        timezone: "Europe/Madrid"
      )

      expect { person.destroy }.to change(Person, :count).by(-1)
      expect(Booking.exists?(booking.id)).to be(true)
      expect(booking.reload.person_id).to be_nil
    end
  end
end
