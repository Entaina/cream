require "rails_helper"

RSpec.describe "Tasks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }

  describe "POST /tasks from deal" do
    it "creates a task linked to the deal" do
      sign_in_as(member)

      expect {
        post tasks_path, params: {
          task: { title: "Follow up call", due_on: (Date.current + 2).to_s },
          taskable_type: "Deal",
          taskable_id: deal.id
        }, headers: { "HTTP_REFERER" => deal_url(deal) }
      }.to change { deal.tasks.count }.by(1)

      expect(response).to redirect_to(deal_url(deal))
      task = deal.tasks.order(:id).last
      expect(task.title).to eq("Follow up call")
      expect(task.workspace).to eq(workspace)
    end

    it "creates a task due today" do
      sign_in_as(member)

      expect {
        post tasks_path, params: {
          task: { title: "Call today", due_on: Date.current.to_s },
          taskable_type: "Deal",
          taskable_id: deal.id
        }, headers: { "HTTP_REFERER" => deal_url(deal) }
      }.to change { deal.tasks.count }.by(1)

      expect(deal.tasks.order(:id).last.due_on).to eq(Date.current)
    end

    it "assigns the task to the mentioned user" do
      sign_in_as(member)
      mentioned = users(:two)

      post tasks_path, params: {
        task: { title: "Please review @two", due_on: (Date.current + 2).to_s },
        taskable_type: "Deal",
        taskable_id: deal.id
      }, headers: { "HTTP_REFERER" => deal_url(deal) }

      task = deal.tasks.order(:id).last
      expect(task.assignee).to eq(mentioned)
    end
  end

  describe "PATCH /tasks/:id" do
    let(:assignee) { users(:two) }
    let!(:task) do
      deal.tasks.create!(
        title: "Original title",
        due_on: Date.current + 1,
        workspace: workspace,
        user: member,
        assignee: member
      )
    end

    it "updates the task title, due date and assignee" do
      sign_in_as(member)
      new_due = Date.current + 5

      patch task_path(task), params: {
        task: { title: "Updated title", due_on: new_due.to_s, assignee_id: assignee.id }
      }, headers: { "HTTP_REFERER" => tasks_url }

      expect(response).to redirect_to(tasks_url)
      task.reload
      expect(task.title).to eq("Updated title")
      expect(task.due_on).to eq(new_due)
      expect(task.assignee).to eq(assignee)
    end
  end
end
