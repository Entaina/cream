require "rails_helper"

RSpec.describe PersonMerger do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { create_company!(workspace) }

  before do
    Current.session = user.sessions.create!
    Current.workspace = workspace
  end

  def merge(primary:, secondaries:)
    described_class.call(primary: primary, secondaries: secondaries, user: user)
  end

  it "reassigns notes, tasks and deals to the primary contact" do
    primary = create_person!(workspace, company: company, first_name: "Primary", email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "pat@acme.com")
    deal = create_deal!(workspace, company: company, contacts: [secondary])
    note = secondary.notes.create!(body: "Met at conference", user: user, workspace: workspace)
    task = secondary.tasks.create!(title: "Follow up", due_on: Date.current + 1, workspace: workspace, user: user, assignee: user)

    result = merge(primary: primary, secondaries: [secondary])

    expect(result).to eq(primary)
    expect(Person.exists?(secondary.id)).to be(false)
    expect(note.reload.notable).to eq(primary)
    expect(task.reload.taskable).to eq(primary)
    expect(primary.deals).to include(deal)
    expect(deal.reload.contacts).to eq([primary])
  end

  it "deduplicates deal_contacts when both contacts are on the same deal" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    deal = create_deal!(workspace, company: company, contacts: [primary])
    deal.deal_contacts.create!(person: secondary)

    merge(primary: primary, secondaries: [secondary])

    expect(DealContact.where(deal_id: deal.id, person_id: primary.id).count).to eq(1)
    expect(DealContact.where(person_id: secondary.id)).to be_empty
  end

  it "reassigns person relationships and drops self-links" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    third = create_person!(workspace, company: company, first_name: "Third")
    invited = PersonRelationship.create!(from_person: secondary, to_person: third, relationship_type: "invited")
    PersonRelationship.create!(from_person: third, to_person: secondary, relationship_type: "referred_by")

    merge(primary: primary, secondaries: [secondary])

    expect(PersonRelationship.exists?(invited.id)).to be(true)
    expect(invited.reload.from_person).to eq(primary)
    expect(PersonRelationship.where(from_person_id: primary.id, to_person_id: primary.id)).to be_empty
    expect(PersonRelationship.where(from_person_id: third.id, to_person_id: primary.id, relationship_type: "referred_by").count).to eq(1)
  end

  it "merges when the secondary is preloaded with deals (controller includes pattern)" do
    primary = create_person!(workspace, company: company, first_name: "Pedro Gonzalo", email: "pedro@example.com")
    secondary = create_person!(workspace, company: company, first_name: "pedro gonzalo", email: "pedro@example.com")
    deal = create_deal!(workspace, company: company, contacts: [secondary])

    preloaded_secondary = Person.where(id: secondary.id).includes(:deals).first

    merge(primary: primary, secondaries: [preloaded_secondary])

    expect(Person.exists?(secondary.id)).to be(false)
    expect(DealContact.where(deal_id: deal.id, person_id: primary.id).count).to eq(1)
    expect(primary.reload.deals).to include(deal)
  end

  it "deduplicates list entries when both contacts are on the same list" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    list = workspace.lists.create!(name: "Prospects", record_type: "Person")
    list.list_entries.create!(record: primary)
    list.list_entries.create!(record: secondary)

    merge(primary: primary, secondaries: [secondary])

    expect(ListEntry.where(list_id: list.id, record_type: "Person", record_id: primary.id).count).to eq(1)
    expect(ListEntry.where(record_id: secondary.id)).to be_empty
    expect(primary.lists).to include(list)
  end

  it "keeps primary scalar values and fills blanks from the secondary" do
    primary = create_person!(workspace, company: company, first_name: "Primary", email: "pat@acme.com", phone: "111")
    secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "other@acme.com",
      phone: "222", job_title: "CEO", first_contact_on: Date.new(2024, 1, 1))

    merge(primary: primary, secondaries: [secondary])

    primary.reload
    expect(primary.email).to eq("pat@acme.com")
    expect(primary.person_emails.pluck(:address)).to contain_exactly("pat@acme.com", "other@acme.com")
    expect(primary.phone).to eq("111")
    expect(primary.job_title).to eq("CEO")
    expect(primary.first_contact_on).to eq(Date.new(2024, 1, 1))
  end

  it "adds the secondary legacy email when it has no person_emails records" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "other@acme.com")
    secondary.person_emails.delete_all
    secondary.update_column(:email, "other@acme.com")

    merge(primary: primary, secondaries: [secondary])

    primary.reload
    expect(primary.person_emails.pluck(:address)).to contain_exactly("pat@acme.com", "other@acme.com")
    expect(primary.email).to eq("pat@acme.com")
  end

  it "merges multiple secondary emails without duplicating the primary address" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "other@acme.com")
    secondary.add_email!("work@acme.com", primary: false)

    merge(primary: primary, secondaries: [secondary])

    primary.reload
    expect(primary.person_emails.pluck(:address)).to contain_exactly("pat@acme.com", "other@acme.com", "work@acme.com")
    expect(primary.person_emails.where(primary: true).pluck(:address)).to eq(["pat@acme.com"])
  end

  it "does not copy a legacy team member source without brought_by" do
    primary = create_person!(workspace, company: company, first_name: "Primary", email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "pat@acme.com")
    secondary.update_columns(source: "team_member", brought_by_id: nil)

    merge(primary: primary, secondaries: [secondary])

    expect(Person.exists?(secondary.id)).to be(false)
    expect(primary.reload.source).to be_blank
  end

  it "merges custom field values, keeping the primary when both have values" do
    field = workspace.custom_fields.create!(record_type: "Person", name: "Tier", field_type: "text")
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    primary.update!(custom_fields: {field.key => "Gold"})
    secondary.update!(custom_fields: {field.key => "Silver"})

    merge(primary: primary, secondaries: [secondary])

    expect(primary.reload.custom_fields_hash[field.key]).to eq("Gold")
  end

  it "fills blank primary custom field values from the secondary" do
    field = workspace.custom_fields.create!(record_type: "Person", name: "Region", field_type: "text")
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary.update!(custom_fields: {field.key => "EMEA"})

    merge(primary: primary, secondaries: [secondary])

    expect(primary.reload.custom_fields_hash[field.key]).to eq("EMEA")
  end

  it "updates record reference custom fields pointing at the secondary" do
    field = workspace.custom_fields.create!(record_type: "Person", name: "Buddy", field_type: "record_reference",
      reference_type: "Person")
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    holder = create_person!(workspace, company: company, first_name: "Holder")
    holder.update!(custom_fields: {field.key => secondary.id})

    merge(primary: primary, secondaries: [secondary])

    expect(holder.reload.custom_fields_hash[field.key]).to eq(primary.id)
  end

  it "merges contacts from different companies into the primary company" do
    other_company = create_company!(workspace)
    primary = create_person!(workspace, company: company, email: "pat@acme.com", first_name: "Primary")
    secondary = create_person!(workspace, company: other_company, email: "pat@acme.com", first_name: "Secondary")
    deal = create_deal!(workspace, company: other_company, contacts: [secondary])

    merge(primary: primary, secondaries: [secondary])

    expect(Person.exists?(secondary.id)).to be(false)
    expect(primary.reload.company).to eq(company)
    expect(DealContact.where(deal_id: deal.id, person_id: primary.id).count).to eq(1)
  end

  it "logs a merged activity on the primary contact" do
    primary = create_person!(workspace, company: company, first_name: "Primary", email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, first_name: "Secondary", email: "pat@acme.com")

    expect {
      merge(primary: primary, secondaries: [secondary])
    }.to change { primary.activities.where(action: "merged").count }.by(1)

    activity = primary.activities.where(action: "merged").last
    expect(activity.metadata["merged_people"].first["name"]).to eq("Secondary Doe")
  end

  it "reassigns bookings to the primary contact" do
    primary = create_person!(workspace, company: company, email: "pat@acme.com")
    secondary = create_person!(workspace, company: company, email: "pat@acme.com")
    pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    booking_page = workspace.booking_pages.new(
      name: "Agenda",
      slug: "merger-booking-#{SecureRandom.hex(3)}",
      host: user,
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
    booking = Booking.create!(
      workspace: workspace,
      booking_page: booking_page,
      booking_event_type: event_type,
      person: secondary,
      first_name: "Ana",
      last_name: "Lopez",
      email: "ana@example.com",
      starts_at: Time.zone.parse("2026-08-10 10:00"),
      ends_at: Time.zone.parse("2026-08-10 10:30"),
      timezone: "Europe/Madrid"
    )

    merge(primary: primary, secondaries: [secondary])

    expect(Person.exists?(secondary.id)).to be(false)
    expect(booking.reload.person_id).to eq(primary.id)
  end
end
