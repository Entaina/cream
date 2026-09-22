require "rails_helper"

RSpec.describe "Notifications", type: :request do
  fixtures :users, :workspaces, :memberships, :notifications

  let(:member) { users(:two) }

  it "lists notifications for the signed-in user" do
    sign_in_as(member)
    patch switch_workspace_path, params: {workspace_id: workspaces(:one).id}

    get notifications_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include(notifications(:mention).title)
  end

  it "does not duplicate task_overdue notifications after marking one as read" do
    workspace = workspaces(:one)
    sign_in_as(member)
    patch switch_workspace_path, params: {workspace_id: workspace.id}

    person = create_person!(workspace)
    person.tasks.create!(
      title: "Overdue follow-up",
      due_on: Date.current - 1,
      workspace: workspace,
      user: member,
      assignee: member
    )

    expect {
      get notifications_path
    }.to change { member.notifications.where(kind: "task_overdue").count }.by(1)

    notification = member.notifications.find_by!(kind: "task_overdue", body: "Overdue follow-up")

    patch notification_path(notification), headers: {"HTTP_REFERER" => notifications_url}

    expect {
      get notifications_path
    }.not_to change { member.notifications.where(kind: "task_overdue").count }
  end
end
