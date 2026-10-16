class NotificationService
  def self.notify_mention(recipient:, actor:, comment:)
    record = comment.commentable
    with_recipient_locale(recipient) do
      recipient.notifications.create!(
        workspace: comment.workspace,
        actor: actor,
        kind: "mention",
        title: I18n.t("notifications.events.mention.title", actor: actor.name),
        body: comment.body.truncate(120),
        url: record_path_for(record)
      )
    end
  end

  def self.notify_task_overdue(task:)
    return unless task.assignee

    with_recipient_locale(task.assignee) do
      task.assignee.notifications.create!(
        workspace: task.workspace,
        kind: "task_overdue",
        title: I18n.t("notifications.events.task_overdue.title"),
        body: task.title,
        url: record_path_for(task.taskable)
      )
    end
  end

  def self.notify_email_opened(message:)
    with_recipient_locale(message.user) do
      message.user.notifications.create!(
        workspace: message.workspace,
        actor: nil,
        kind: "email_opened",
        title: I18n.t("notifications.events.email_opened.title"),
        body: I18n.t("notifications.events.email_opened.body",
          address: message.to_address, subject: message.subject),
        url: record_path_for(message.record)
      )
    end
  end

  def self.notify_email_followup(message:)
    with_recipient_locale(message.user) do
      message.user.notifications.create!(
        workspace: message.workspace,
        actor: nil,
        kind: "email_followup",
        title: I18n.t("notifications.events.email_followup.title"),
        body: I18n.t("notifications.events.email_followup.body",
          address: message.to_address, subject: message.subject),
        url: record_path_for(message.record)
      )
    end
  end

  def self.notify_email_replied(message:)
    with_recipient_locale(message.user) do
      message.user.notifications.create!(
        workspace: message.workspace,
        actor: nil,
        kind: "email_replied",
        title: I18n.t("notifications.events.email_replied.title"),
        body: I18n.t("notifications.events.email_replied.body",
          address: message.to_address, subject: message.subject),
        url: record_path_for(message.record)
      )
    end
  end

  def self.notify_lead_submission(responsible:, lead_form:, deal:, person:)
    with_recipient_locale(responsible) do
      responsible.notifications.create!(
        workspace: lead_form.workspace,
        kind: "lead_submission",
        title: I18n.t("notifications.events.lead_submission.title"),
        body: I18n.t("notifications.events.lead_submission.body",
          form: lead_form.name, person: person.display_name, email: person.email),
        url: record_path_for(deal || person)
      )
    end
  end

  def self.notify_booking(booking:)
    host = booking.booking_page.host
    event_name = booking.booking_event_type.localized_name
    when_label = booking.localized_starts_at_with_zone

    with_recipient_locale(host) do
      host.notifications.create!(
        workspace: booking.workspace,
        kind: "booking",
        title: I18n.t("notifications.events.booking.title"),
        body: I18n.t("notifications.events.booking.body",
          event: event_name, name: booking.display_name, email: booking.email, when: when_label),
        url: record_path_for(booking.deal || booking.person) || Rails.application.routes.url_helpers.bookings_path
      )
    end
  end

  def self.notify_alert(recipient:, rule:, deal:)
    company_name = deal.company&.name
    body = company_name.present? ? "#{deal.name} (#{company_name})" : deal.name

    recipient.notifications.create!(
      workspace: rule.workspace,
      kind: "alert",
      title: rule.name,
      body: body,
      url: record_path_for(deal)
    )
  end

  def self.check_overdue_tasks!(workspace)
    workspace.tasks.pending.where("due_on < ?", Date.current).find_each do |task|
      next unless task.assignee
      next if task.assignee.notifications.exists?(kind: "task_overdue", body: task.title)

      notify_task_overdue(task: task)
    end
  end

  def self.with_recipient_locale(user, &block)
    locale = user.locale.to_s.presence_in(User::LOCALES) || I18n.default_locale
    I18n.with_locale(locale, &block)
  end

  def self.record_path_for(record)
    return nil unless record

    case record
    when Person then Rails.application.routes.url_helpers.person_path(record)
    when Company then Rails.application.routes.url_helpers.company_path(record)
    when Deal then Rails.application.routes.url_helpers.deal_path(record)
    end
  end
  private_class_method :record_path_for
end
