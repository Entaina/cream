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

  describe ".notify_booking_page_invite" do
    let(:pipeline) { Pipeline.default_for(workspace) || Pipeline.create_default!(workspace) }
    let(:booking_page) do
      page = workspace.booking_pages.new(
        name: "Agenda comercial", slug: "invite-test", host: actor, pipeline: pipeline,
        timezone: "Europe/Madrid", calendar_ids: ["primary"]
      )
      page.event_types.build(BookingEventType.blank_attributes.merge(slug: "call", name_i18n: {"es" => "Llamada"}))
      page.save!
      page
    end

    it "tells the invited user to pick calendars, in their locale, linking to the page editor" do
      recipient.update!(locale: "en")

      described_class.notify_booking_page_invite(recipient: recipient, booking_page: booking_page, actor: actor)

      notification = recipient.notifications.order(:id).last
      expect(notification.kind).to eq("booking_page_invite")
      expect(notification.actor).to eq(actor)
      expect(notification.title).to eq(I18n.t("notifications.events.booking_page_invite.title", locale: :en))
      expect(notification.body).to include(actor.name, "Agenda comercial")
      expect(notification.url).to eq(Rails.application.routes.url_helpers.edit_booking_page_path(booking_page))
    end
  end
end
