class NotificationService
  def self.notify_mention(recipient:, actor:, comment:)
    record = comment.commentable
    recipient.notifications.create!(
      workspace: comment.workspace,
      actor: actor,
      kind: "mention",
      title: "#{actor.name} mentioned you",
      body: comment.body.truncate(120),
      url: record_path_for(record)
    )
  end

  def self.notify_task_overdue(task:)
    return unless task.assignee

    task.assignee.notifications.create!(
      workspace: task.workspace,
      kind: "task_overdue",
      title: "Task overdue",
      body: task.title,
      url: record_path_for(task.taskable)
    )
  end

  def self.notify_email_opened(message:)
    message.user.notifications.create!(
      workspace: message.workspace,
      actor: nil,
      kind: "email_opened",
      title: "Email opened",
      body: "#{message.to_address} opened “#{message.subject}”",
      url: record_path_for(message.record)
    )
  end

  def self.notify_email_followup(message:)
    message.user.notifications.create!(
      workspace: message.workspace,
      actor: nil,
      kind: "email_followup",
      title: "Follow up",
      body: "No reply yet from #{message.to_address} to “#{message.subject}”",
      url: record_path_for(message.record)
    )
  end

  def self.notify_email_replied(message:)
    message.user.notifications.create!(
      workspace: message.workspace,
      actor: nil,
      kind: "email_replied",
      title: "Email replied",
      body: "#{message.to_address} replied to “#{message.subject}”",
      url: record_path_for(message.record)
    )
  end

  def self.notify_lead_submission(responsible:, lead_form:, deal:, person:)
    responsible.notifications.create!(
      workspace: lead_form.workspace,
      kind: "lead_submission",
      title: "New lead",
      body: "#{lead_form.name}: #{person.display_name} (#{person.email})",
      url: record_path_for(deal)
    )
  end

  def self.notify_booking(booking:)
    host = booking.booking_page.host
    zone = ActiveSupport::TimeZone[booking.timezone] || Time.zone
    starts_at = booking.starts_at.in_time_zone(zone)
    event_name = booking.booking_event_type.localized_name

    host.notifications.create!(
      workspace: booking.workspace,
      kind: "booking",
      title: "New booking",
      body: "#{event_name}: #{booking.display_name} (#{booking.email}) — #{starts_at.strftime('%Y-%m-%d %H:%M')}",
      url: record_path_for(booking.deal) || Rails.application.routes.url_helpers.bookings_path
    )
  end

  def self.notify_alert(recipient:, rule:, deal:)
    recipient.notifications.create!(
      workspace: rule.workspace,
      kind: "alert",
      title: rule.name,
      body: "#{deal.name} (#{deal.company.name})",
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
