require "rails_helper"

RSpec.describe WorkspaceScopedAssociations, type: :model do
  fixtures :workspaces, :companies, :users, :memberships

  let(:workspace_one) { workspaces(:one) }
  let(:workspace_two) { workspaces(:two) }
  let(:company_one) { companies(:acme) }
  let(:company_two) { companies(:globex) }
  let(:user) { users(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace_one) }
  let(:foreign_person) { create_person!(workspace_two, company: company_two) }

  describe Person do
    it "rejects a company from another workspace" do
      person = workspace_one.people.build(first_name: "Test", company: company_two, owner: user)

      expect(person).not_to be_valid
      expect(person.errors[:company]).to be_present
    end

    it "lets a person saved with a foreign company be edited, but not moved to one" do
      person = create_person!(workspace_one, company: company_one)
      person.update_column(:company_id, company_two.id)

      expect(person.reload.update(first_name: "Renamed")).to be(true)

      person.update_column(:company_id, company_one.id)
      expect(person.reload.update(company: company_two)).to be(false)
      expect(person.errors[:company]).to be_present
    end
  end

  describe Deal do
    def build_deal(**attrs)
      workspace_one.deals.build({name: "Cross", company: company_one, pipeline: pipeline,
                                 pipeline_stage: pipeline.first_stage, owner: user}.merge(attrs))
    end

    it "rejects a company from another workspace" do
      deal = build_deal(company: company_two)

      expect(deal).not_to be_valid
      expect(deal.errors[:company]).to be_present
    end

    it "rejects a partner from another workspace" do
      deal = build_deal(partner: company_two)

      expect(deal).not_to be_valid
      expect(deal.errors[:partner]).to be_present
    end

    it "rejects a pipeline stage from another workspace" do
      foreign_pipeline = Pipeline.create_default!(workspace_two)
      deal = build_deal(pipeline: foreign_pipeline, pipeline_stage: foreign_pipeline.first_stage)

      expect(deal).not_to be_valid
      expect(deal.errors[:pipeline]).to be_present
      expect(deal.errors[:pipeline_stage]).to be_present
    end

    it "rejects contacts from another workspace on create" do
      deal = build_deal(contacts: [foreign_person])

      expect(deal).not_to be_valid
      expect(deal.errors[:contacts]).to be_present
    end

    it "rejects adding a contact from another workspace to an existing deal" do
      deal = create_deal!(workspace_one, pipeline: pipeline)

      expect { deal.contact_ids = deal.contact_ids + [foreign_person.id] }.to raise_error(ActiveRecord::RecordInvalid)
      expect(deal.reload.contacts).not_to include(foreign_person)
    end

    it "lets a deal linked to foreign records before these checks be edited" do
      deal = create_deal!(workspace_one, pipeline: pipeline)
      deal.update_column(:company_id, company_two.id)
      DealContact.insert!({deal_id: deal.id, person_id: foreign_person.id, created_at: Time.current, updated_at: Time.current})

      expect(deal.reload.update(name: "Renamed")).to be(true)
    end

    it "still accepts an owner who is no longer a workspace member" do
      deal = build_deal(owner: users(:outsider), tasks: [Task.new(title: "Next", due_on: Date.current + 3,
        workspace: workspace_one, user: user, assignee: user)])

      expect(deal).to be_valid
    end
  end

  describe DealContact do
    let(:deal) { create_deal!(workspace_one, pipeline: pipeline) }

    it "rejects a person from another workspace" do
      join = deal.deal_contacts.build(person: foreign_person)

      expect(join).not_to be_valid
      expect(join.errors[:person]).to be_present
    end
  end

  describe DealProduct do
    it "rejects a product from another workspace" do
      deal = create_deal!(workspace_one, pipeline: pipeline)
      line = deal.deal_products.build(product: workspace_two.products.create!(name: "Foreign", price: 10), quantity: 1)

      expect(line).not_to be_valid
      expect(line.errors[:product]).to be_present
    end
  end

  describe Task do
    it "rejects a record from another workspace" do
      task = workspace_one.tasks.build(title: "Call", user: user, assignee: user, taskable: company_two)

      expect(task).not_to be_valid
      expect(task.errors[:taskable]).to be_present
    end

    it "still accepts an assignee who is no longer a workspace member" do
      task = workspace_one.tasks.build(title: "Call", user: users(:outsider), assignee: users(:outsider), taskable: company_one)

      expect(task).to be_valid
    end

    it "lets a task on a foreign record be completed" do
      task = workspace_one.tasks.create!(title: "Call", user: user, assignee: user, taskable: company_one)
      task.update_columns(taskable_id: company_two.id)

      task.reload.toggle_completed!

      expect(task.reload).to be_completed
    end
  end

  describe Note do
    it "rejects a record from another workspace" do
      note = workspace_one.notes.build(body: "Hi", user: user, notable: company_two)

      expect(note).not_to be_valid
      expect(note.errors[:notable]).to be_present
    end
  end

  describe Comment do
    it "rejects a record from another workspace" do
      comment = workspace_one.comments.build(body: "Hi", user: user, commentable: company_two)

      expect(comment).not_to be_valid
      expect(comment.errors[:commentable]).to be_present
    end

    it "rejects replying to a comment from another workspace" do
      parent = workspace_two.comments.create!(body: "Root", user: users(:two), commentable: company_two)
      reply = workspace_one.comments.build(body: "Re", user: user, commentable: company_one, parent: parent)

      expect(reply).not_to be_valid
      expect(reply.errors[:parent]).to be_present
    end
  end

  describe Campaign do
    it "rejects an email template from another workspace" do
      campaign = workspace_one.campaigns.build(name: "Marzo", status: "draft",
        email_template: create_email_template!(workspace_two, user: users(:two)))

      expect(campaign).not_to be_valid
      expect(campaign.errors[:email_template]).to be_present
    end
  end

  describe EmailTemplate do
    it "rejects a layout from another workspace" do
      template = workspace_one.email_templates.build(name: "Mine", subject: "Hi", body: "<p>Hi</p>", user: user,
        email_layout: workspace_two.email_layouts.create!(name: "Foreign", body: "<div>{{ content }}</div>"))

      expect(template).not_to be_valid
      expect(template.errors[:email_layout]).to be_present
    end
  end

  describe SegmentMembership do
    it "rejects a person from another workspace" do
      segment = workspace_one.segments.create!(name: "Hot", record_type: "Person", user: user)
      membership = workspace_one.segment_memberships.build(segment: segment, person: foreign_person, entered_at: Time.current)

      expect(membership).not_to be_valid
      expect(membership.errors[:person]).to be_present
    end
  end

  describe JourneyEnrollment do
    it "rejects a person from another workspace" do
      journey = workspace_one.journeys.create!(name: "Nurture", entry_trigger: "manual", max_reenrollments: 0, active: true)
      enrollment = JourneyEnrollment.new(workspace: workspace_one, journey: journey, person: foreign_person, state: "active")

      expect(enrollment).not_to be_valid
      expect(enrollment.errors[:person]).to be_present
    end
  end

  describe BookingEventType do
    it "rejects an email template from another workspace" do
      page = workspace_one.booking_pages.new(name: "Agenda", slug: "agenda-scope", host: user, pipeline: pipeline,
        timezone: "Europe/Madrid", calendar_ids: ["primary"])
      event_type = page.event_types.build(email_template: create_email_template!(workspace_two, user: users(:two)))

      event_type.valid?

      expect(event_type.errors[:email_template]).to be_present
    end
  end

  describe Booking do
    it "rejects a person from another workspace" do
      booking = Booking.new(workspace: workspace_one, person: foreign_person)

      booking.valid?

      expect(booking.errors[:person]).to be_present
    end
  end

  describe ListEntry do
    it "rejects a record from another workspace" do
      list = workspace_one.lists.create!(name: "Targets", record_type: "Company")
      entry = list.list_entries.build(record: company_two)

      expect(entry).not_to be_valid
      expect(entry.errors[:record]).to be_present
    end

    it "accepts a record from the list workspace" do
      list = workspace_one.lists.create!(name: "Targets", record_type: "Company")

      expect(list.list_entries.build(record: company_one)).to be_valid
    end
  end
end
