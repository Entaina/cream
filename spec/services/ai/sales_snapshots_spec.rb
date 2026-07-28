require "rails_helper"

RSpec.describe Ai::SalesSnapshots do
  fixtures :users, :workspaces

  let(:workspace) { workspaces(:one) }
  let(:actor) { users(:one) }
  let(:briefing_date) { Date.new(2026, 7, 28) }

  def build_deal(name: "Delta Furniture", task_due_on: nil, task_title: "Follow-up call", extra_tasks: [])
    company = create_company!(workspace, name: "Delta Co")
    pipeline = Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    tasks = extra_tasks
    if task_due_on
      tasks << Task.new(
        title: task_title,
        due_on: task_due_on,
        workspace: workspace,
        user: actor,
        assignee: actor
      )
    end
    workspace.deals.create!(
      name: name,
      pipeline: pipeline,
      pipeline_stage: pipeline.first_stage,
      company: company,
      owner: actor,
      tasks: tasks
    )
  end

  describe ".deal_snapshot" do
    it "includes scheduled next action and omits inactivity when a future task exists" do
      deal = build_deal(task_due_on: briefing_date + 21.days, task_title: "Llamada comercial")
      allow(deal).to receive(:magic_column_value).with(:days_in_stage).and_return(13)
      allow(deal).to receive(:magic_column_value).with(:last_activity_at).and_return(13.days.ago)

      snapshot = described_class.deal_snapshot(deal, briefing_date:)

      expect(snapshot[:has_scheduled_next_action]).to be(true)
      expect(snapshot[:next_action]).to include(
        title: "Llamada comercial",
        due_on: (briefing_date + 21.days).iso8601,
        status: "scheduled"
      )
      expect(snapshot).not_to have_key(:days_since_last_activity)
      expect(snapshot).not_to have_key(:last_activity_at)
    end

    it "flags missing next action when there are no open tasks" do
      deal = build_deal(task_due_on: briefing_date + 1.day)
      deal.tasks.destroy_all

      snapshot = described_class.deal_snapshot(deal.reload, briefing_date:)

      expect(snapshot[:missing_next_action]).to be(true)
      expect(snapshot).not_to have_key(:next_action)
      expect(snapshot).not_to have_key(:has_scheduled_next_action)
    end

    it "marks overdue next actions without scheduled protection" do
      deal = build_deal(task_due_on: briefing_date + 1.day, task_title: "Call back")
      deal.tasks.first.update!(due_on: briefing_date - 1.day)
      allow(deal).to receive(:magic_column_value).with(:days_in_stage).and_return(5)
      allow(deal).to receive(:magic_column_value).with(:last_activity_at).and_return(10.days.ago)

      snapshot = described_class.deal_snapshot(deal, briefing_date:)

      expect(snapshot[:next_action][:status]).to eq("overdue")
      expect(snapshot).not_to have_key(:has_scheduled_next_action)
      expect(snapshot[:days_since_last_activity]).to eq(10)
    end

    it "marks due today actions as actionable, not scheduled" do
      deal = build_deal(task_due_on: briefing_date, task_title: "Check-in today")

      snapshot = described_class.deal_snapshot(deal, briefing_date:)

      expect(snapshot[:next_action][:status]).to eq("due_today")
      expect(snapshot).not_to have_key(:has_scheduled_next_action)
    end

    it "picks the earliest dated pending task as next action" do
      deal = build_deal(
        task_due_on: briefing_date + 14.days,
        task_title: "Later call",
        extra_tasks: [
          Task.new(
            title: "Sooner call",
            due_on: briefing_date + 3.days,
            workspace: workspace,
            user: actor,
            assignee: actor
          )
        ]
      )

      snapshot = described_class.deal_snapshot(deal, briefing_date:)

      expect(snapshot[:next_action][:title]).to eq("Sooner call")
    end
  end
end
