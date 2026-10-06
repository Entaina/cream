require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:company) { create_company!(workspace) }
  let(:token) { user.api_tokens.create!(name: "Test", workspace: workspace) }
  let(:headers) { {"Authorization" => "Bearer #{token.plaintext_token}"} }

  def create_task!(**attrs)
    workspace.tasks.create!(
      {title: "Follow up", user: user, assignee: user, taskable: company}.merge(attrs)
    )
  end

  describe "GET /api/v1/tasks" do
    it "lists tasks with timestamps" do
      task = create_task!

      get "/api/v1/tasks", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.first).to include(
        "id" => task.id,
        "title" => "Follow up",
        "completed" => false,
        "completed_at" => nil,
        "created_at" => task.created_at.iso8601,
        "updated_at" => task.updated_at.iso8601
      )
    end
  end

  describe "GET /api/v1/tasks/:id" do
    it "returns a single task" do
      task = create_task!

      get "/api/v1/tasks/#{task.id}", headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        "id" => task.id,
        "taskable_type" => "Company",
        "taskable_id" => company.id
      )
    end
  end

  describe "POST /api/v1/tasks" do
    it "creates a task with timestamps" do
      post "/api/v1/tasks",
        params: {
          task: {
            title: "Call client",
            due_on: "2026-08-10",
            taskable_type: "Company",
            taskable_id: company.id
          }
        },
        headers: headers

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      task = workspace.tasks.find(body["id"])
      expect(body).to include(
        "title" => "Call client",
        "due_on" => "2026-08-10",
        "completed" => false,
        "assignee_id" => user.id,
        "created_at" => task.created_at.iso8601,
        "updated_at" => task.updated_at.iso8601
      )
    end

    it "creates a completed task without side effects" do
      post "/api/v1/tasks",
        params: {task: {title: "Done on create", completed: true}},
        headers: headers

      expect(response).to have_http_status(:created)
      task = workspace.tasks.find(response.parsed_body["id"])
      expect(task.completed?).to be(true)
      expect(task.completed_at).to be_present
      expect(company.activities.where(action: "task_completed")).to be_empty
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    it "updates fields and returns timestamps" do
      task = create_task!

      patch "/api/v1/tasks/#{task.id}",
        params: {task: {title: "Updated title"}},
        headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include(
        "title" => "Updated title",
        "updated_at" => task.reload.updated_at.iso8601
      )
    end

    it "completes a task via toggle side effects" do
      task = create_task!

      expect {
        patch "/api/v1/tasks/#{task.id}", params: {task: {completed: true}}, headers: headers
      }.to change { company.activities.where(action: "task_completed").count }.by(1)

      body = response.parsed_body
      expect(body["completed"]).to be(true)
      expect(body["completed_at"]).to be_present
    end

    it "reopens a completed task" do
      task = create_task!(completed_at: 1.hour.ago)

      patch "/api/v1/tasks/#{task.id}", params: {task: {completed: false}}, headers: headers

      expect(response).to have_http_status(:success)
      expect(response.parsed_body["completed"]).to be(false)
      expect(response.parsed_body["completed_at"]).to be_nil
    end
  end

  describe "POST /api/v1/tasks/:id/complete_and_replace" do
    it "completes the task and creates the next one atomically" do
      task = create_task!(due_on: Date.current + 2.days)

      expect {
        post "/api/v1/tasks/#{task.id}/complete_and_replace",
          params: {next_task: {title: "Schedule demo", due_on: (Date.current + 1.day).iso8601}},
          headers: headers
      }.to change { company.activities.where(action: "task_completed").count }.by(1)
        .and change { workspace.tasks.pending.count }.by(0)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["completed_task"]).to include("id" => task.id, "completed" => true)
      expect(body["next_task"]).to include(
        "title" => "Schedule demo",
        "completed" => false,
        "taskable_type" => "Company",
        "taskable_id" => company.id
      )
      expect(task.reload.completed?).to be(true)
    end

    it "returns 422 and leaves the task pending when validation fails" do
      task = create_task!

      expect {
        post "/api/v1/tasks/#{task.id}/complete_and_replace",
          params: {next_task: {title: "", due_on: (Date.current + 1.day).iso8601}},
          headers: headers
      }.not_to change { workspace.tasks.count }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Title can't be blank")
      expect(task.reload.completed?).to be(false)
    end

    it "rejects a past due date for the next task" do
      task = create_task!

      post "/api/v1/tasks/#{task.id}/complete_and_replace",
        params: {next_task: {title: "Call back", due_on: (Date.current - 1.day).iso8601}},
        headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Due date must be today or later")
      expect(task.reload.completed?).to be(false)
    end

    it "rejects when the task is already completed" do
      task = create_task!(completed_at: 1.hour.ago)

      post "/api/v1/tasks/#{task.id}/complete_and_replace",
        params: {next_task: {title: "Call back", due_on: (Date.current + 1.day).iso8601}},
        headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"]).to include("Task is already completed")
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    it "destroys the task" do
      task = create_task!

      expect {
        delete "/api/v1/tasks/#{task.id}", headers: headers
      }.to change { workspace.tasks.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
