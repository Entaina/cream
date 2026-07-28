class AutomationEngine
  def self.run(event:, record:, metadata: {})
    workspace = record.workspace
    workspace.automations.for_event(event).find_each do |automation|
      next unless conditions_match?(automation, record, metadata)

      run_action(automation, record, metadata)
    end
  end

  def self.conditions_match?(automation, record, metadata)
    conditions = automation.trigger_conditions
    return true if conditions.blank?

    conditions.all? do |key, expected|
      actual = metadata[key] || record.try(key)
      actual.to_s == expected.to_s
    end
  end

  def self.run_action(automation, record, metadata)
    case automation.action_type
    when "create_task"
      actor = record.try(:owner) || automation.workspace.users.first
      record.tasks.create!(
        workspace: automation.workspace,
        title: automation.action_params["title"].presence || "Follow up",
        due_on: automation.action_params["due_on"].presence&.to_date || 1.week.from_now.to_date,
        user: actor,
        assignee: actor
      )
    when "send_email"
      # Gated: send_email depends on the incomplete record_email feature.
      return unless CreamFeatures.enabled?(:record_email)

      to = record.try(:email) || record.contacts.first&.email
      return unless to

      RecordMailer.record_email(
        to: to,
        subject: automation.action_params["subject"] || "Follow up",
        body: automation.action_params["body"] || "Checking in.",
        record: record,
        user: record.owner || automation.workspace.users.first
      ).deliver_later
    when "notify_slack"
      # Gated: notify_slack depends on the incomplete slack_integrations feature.
      return unless CreamFeatures.enabled?(:slack_integrations)

      SlackNotifier.notify(
        workspace: automation.workspace,
        event: automation.trigger_event,
        message: "#{record.class.name} #{record.display_name}: #{automation.name}"
      )
    end
  end
end
