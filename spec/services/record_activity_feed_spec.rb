require "rails_helper"

RSpec.describe RecordActivityFeed do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace) }

  def note!(body, at: Time.current)
    person.notes.create!(workspace: workspace, user: user, body: body, created_at: at)
  end

  it "combines content in chronological order without duplicate note or email creation events" do
    note = note!("Earlier note", at: 2.days.ago)
    email = person.email_messages.create!(workspace: workspace, user: user, to_address: "test@example.com", subject: "Reply", body: "Latest reply", direction: "inbound", status: "received")
    person.track_activity("email_sent", metadata: {email_message_id: email.id})

    entries = described_class.new(person).entries
    expect(entries.index(email)).to be < entries.index(note)
    expect(entries.grep(Activity).map(&:action)).not_to include("note_added", "email_sent")
    expect(entries.grep(Note)).to eq([note])
  end

  it "filters before pagination so older notes are still accessible" do
    32.times { |i| note!("Note #{i}") }
    feed = described_class.new(person, filter: "notes", page: 2)

    expect(feed.pages).to eq(2)
    expect(feed.entries.size).to eq(2)
    expect(feed.entries.map(&:body)).to eq(["Note 1", "Note 0"])
  end

  it "paginates entries with identical timestamps without losing or repeating them" do
    timestamp = Time.current.change(usec: 0)
    notes = 32.times.map { |i| note!("Note #{i}", at: timestamp) }
    first = described_class.new(person, filter: "notes").entries
    second = described_class.new(person, filter: "notes", page: 2).entries

    expect(first & second).to be_empty
    expect(first + second).to match_array(notes)
  end

  it "normalizes unknown filters and out-of-range pages" do
    feed = described_class.new(person, filter: "invalid", page: 999999)
    expect(feed.filter).to eq("all")
    expect(feed.page).to eq(feed.pages)
    expect(described_class.new(person, page: -1).page).to eq(1)
  end

  it "never includes content belonging to another contact" do
    own_note = note!("My note")
    other = create_person!(workspace)
    other.notes.create!(workspace: workspace, user: user, body: "Someone else's note")

    expect(described_class.new(person, filter: "notes").entries).to eq([own_note])
  end

  it "honors disabled email and comment features" do
    person.email_messages.create!(workspace: workspace, user: user, to_address: "test@example.com", subject: "Subject", body: "Body")
    person.comments.create!(workspace: workspace, user: user, body: "Comment")
    person.track_activity("email_opened", metadata: {subject: "Subject"})

    entries = described_class.new(person, emails: false, comments: false).entries
    expect(entries.grep(EmailMessage)).to be_empty
    expect(entries.grep(Comment)).to be_empty
    expect(entries.grep(Activity).map(&:action)).not_to include("email_opened", "comment_added")
  end

  it "works for companies" do
    company = create_company!(workspace)
    note = company.notes.create!(workspace: workspace, user: user, body: "Company note")

    expect(described_class.new(company, filter: "notes").entries).to eq([note])
  end

  describe "deal stage changes on a person feed" do
    let(:pipeline) { Pipeline.create_default!(workspace) }
    let(:company) { create_company!(workspace) }
    let(:contact) { create_person!(workspace, company: company) }
    let(:deal) { create_deal!(workspace, pipeline: pipeline, company: company, contacts: [contact], name: "Person deal") }

    it "includes stage_changed from linked deals in all and changes filters" do
      deal.track_activity("stage_changed", user: user, metadata: {from: "Lead", to: "Qualified", won: false})

      all_entries = described_class.new(contact, deal_ids: [deal.id], filter: "all").entries
      changes_entries = described_class.new(contact, deal_ids: [deal.id], filter: "changes").entries
      notes_entries = described_class.new(contact, deal_ids: [deal.id], filter: "notes").entries

      expect(all_entries.grep(Activity).map(&:action)).to include("stage_changed")
      expect(changes_entries.grep(Activity).map(&:action)).to include("stage_changed")
      expect(notes_entries).to be_empty
    end

    it "excludes stage changes from deals not in deal_ids" do
      other_deal = create_deal!(workspace, pipeline: pipeline, name: "Other deal")
      other_deal.track_activity("stage_changed", user: user, metadata: {from: "Lead", to: "Qualified"})

      entries = described_class.new(contact, deal_ids: [deal.id]).entries
      foreign_stage_changes = entries.grep(Activity).select { |a| a.action == "stage_changed" && a.subject_id == other_deal.id }
      expect(foreign_stage_changes).to be_empty
    end
  end
end
