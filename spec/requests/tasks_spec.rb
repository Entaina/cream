require "rails_helper"

RSpec.describe "Tasks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:sales_director) { users(:three) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }

  def create_workspace_task!(assignee:, title:)
    deal.tasks.create!(
      title: title,
      due_on: Date.current,
      workspace: workspace,
      user: assignee,
      assignee: assignee
    )
  end

  def sign_in_to_workspace!(user)
    sign_in_as(user)
    patch switch_workspace_path, params: { workspace_id: workspace.id }
  end

  describe "GET /tasks" do
    let!(:admin_task) { create_workspace_task!(assignee: member, title: "Admin task") }
    let!(:salesperson_task) { create_workspace_task!(assignee: salesperson, title: "Salesperson task") }

    it "shows only the current user's tasks by default" do
      sign_in_as(member)

      get tasks_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin task")
      expect(response.body).not_to include("Salesperson task")
    end

    context "as admin" do
      it "shows the assignee filter and all tasks when assignee_id=all" do
        sign_in_as(member)

        get tasks_path(assignee_id: "all")

        expect(response.body).to include("Admin task")
        expect(response.body).to include("Salesperson task")
        expect(response.body).to include('name="assignee_id"')
      end

      it "filters by a specific assignee" do
        sign_in_as(member)

        get tasks_path(assignee_id: salesperson.id)

        expect(response.body).not_to include("Admin task")
        expect(response.body).to include("Salesperson task")
      end
    end

    context "as sales director" do
      it "shows the assignee filter and all tasks when assignee_id=all" do
        sign_in_to_workspace!(sales_director)

        get tasks_path(assignee_id: "all")

        expect(response.body).to include("Admin task")
        expect(response.body).to include("Salesperson task")
        expect(response.body).to include('name="assignee_id"')
      end
    end

    context "as salesperson without view-all flag" do
      it "shows only own tasks even when assignee_id=all is requested" do
        sign_in_to_workspace!(salesperson)

        get tasks_path(assignee_id: "all")

        expect(response.body).to include("Salesperson task")
        expect(response.body).not_to include("Admin task")
        expect(response.body).not_to include('name="assignee_id"')
      end
    end

    context "when salespeople_can_view_all_deals is enabled" do
      before { workspace.update!(salespeople_can_view_all_deals: true) }

      it "allows a salesperson to use the assignee filter and view all tasks" do
        sign_in_to_workspace!(salesperson)

        get tasks_path(assignee_id: "all")

        expect(response.body).to include("Admin task")
        expect(response.body).to include("Salesperson task")
        expect(response.body).to include('name="assignee_id"')
      end
    end

    context "when salespeople_can_edit_all_deals is enabled" do
      before { workspace.update!(salespeople_can_edit_all_deals: true) }

      it "allows a salesperson to use the assignee filter" do
        sign_in_to_workspace!(salesperson)

        get tasks_path

        expect(response.body).to include('name="assignee_id"')
      end
    end
  end

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
