require "rails_helper"

RSpec.describe Task, type: :model do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:author) { users(:one) }
  let(:member) { users(:two) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:deal) { create_deal!(workspace, pipeline: pipeline) }

  it "suggests tomorrow as the default due date" do
    expect(Task.default_due_on).to eq(Date.current + 1.day)
  end

  it "assigns the first mentioned workspace user when creating a task" do
    task = workspace.tasks.create!(
      title: "Review @two proposal",
      user: author,
      assignee: author,
      taskable: deal
    )

    expect(task.assignee).to eq(member)
  end

  it "keeps the default assignee when the title has no mention" do
    task = workspace.tasks.create!(
      title: "Follow up call",
      user: author,
      assignee: author,
      taskable: deal
    )

    expect(task.assignee).to eq(author)
  end

  it "ignores mentions that do not match a workspace member" do
    task = workspace.tasks.create!(
      title: "Ping @outsider please",
      user: author,
      assignee: author,
      taskable: deal
    )

    expect(task.assignee).to eq(author)
  end

  it "orders record tasks by due date descending" do
    later = workspace.tasks.create!(title: "Later", user: author, taskable: deal, due_on: Date.current + 10)
    sooner = workspace.tasks.create!(title: "Sooner", user: author, taskable: deal, due_on: Date.current + 1)
    no_due = workspace.tasks.create!(title: "No due", user: author, taskable: deal)

    expect(deal.tasks.where(id: [later.id, sooner.id, no_due.id]).due_order_desc).to eq([later, sooner, no_due])
  end

  it "reassigns when the title changes to include a mention" do
    task = workspace.tasks.create!(
      title: "Follow up call",
      user: author,
      assignee: author,
      taskable: deal
    )

    task.update!(title: "Hand off to @two")

    expect(task.assignee).to eq(member)
  end
end
