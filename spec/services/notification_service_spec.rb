require "rails_helper"

RSpec.describe NotificationService do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:recipient) { users(:two) }
  let(:actor) { users(:one) }

  describe ".notify_task_overdue" do
    it "uses the assignee locale for the title" do
      recipient.update!(locale: "en")
      person = create_person!(workspace)
      task = person.tasks.create!(
        title: "Call back",
        due_on: Date.current - 1,
        workspace: workspace,
        user: recipient,
        assignee: recipient
      )

      described_class.notify_task_overdue(task: task)

      notification = recipient.notifications.order(:id).last
      expect(notification.title).to eq(I18n.t("notifications.events.task_overdue.title", locale: :en))
    end
  end
end
