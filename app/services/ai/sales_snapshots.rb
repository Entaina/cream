module Ai
  module SalesSnapshots
    module_function

    def deal_snapshot(deal, briefing_date:)
      pending_tasks = deal.tasks.reject(&:completed?)
      pending_with_due = pending_tasks.select { |task| task.due_on.present? }
        .sort_by { |task| [ task.due_on, task.id ] }
      next_task = pending_with_due.first
      has_scheduled_next_action = pending_tasks.any? { |task| task.due_on.present? && task.due_on > briefing_date }

      snapshot = {
        id: deal.id,
        name: deal.name,
        pipeline: deal.pipeline.name,
        stage: deal.stage_label,
        value: deal.value.to_f,
        currency: deal.currency,
        owner_id: deal.owner_id,
        owner: deal.owner&.name,
        company: deal.company&.name,
        expected_close_date: deal.expected_close_date&.iso8601,
        days_in_stage: deal.magic_column_value(:days_in_stage)
      }

      snapshot[:missing_next_action] = true if pending_tasks.empty?

      if next_task
        snapshot[:next_action] = {
          id: next_task.id,
          title: next_task.title,
          due_on: next_task.due_on.iso8601,
          status: next_action_status(next_task.due_on, briefing_date:)
        }
      end

      snapshot[:has_scheduled_next_action] = true if has_scheduled_next_action

      unless has_scheduled_next_action
        last_activity = deal.magic_column_value(:last_activity_at)
        days_since_activity = last_activity ? (briefing_date - last_activity.to_date).to_i : nil
        snapshot[:days_since_last_activity] = days_since_activity if days_since_activity
        snapshot[:last_activity_at] = last_activity&.iso8601 if last_activity
      end

      snapshot.compact
    end

    def next_action_status(due_on, briefing_date:)
      if due_on > briefing_date
        "scheduled"
      elsif due_on == briefing_date
        "due_today"
      else
        "overdue"
      end
    end

    def task_snapshot(task)
      {
        id: task.id,
        title: task.title,
        due_on: task.due_on&.iso8601,
        assignee_id: task.assignee_id,
        assignee: task.assignee&.name,
        record_type: task.taskable_type,
        record_id: task.taskable_id,
        record_name: task.taskable&.display_name
      }.compact
    end

    def closed_deal_snapshot(deal)
      {
        id: deal.id,
        name: deal.name,
        stage: deal.stage_label,
        won: deal.pipeline_stage.won?,
        value: deal.value.to_f,
        owner_id: deal.owner_id,
        owner: deal.owner&.name
      }.compact
    end
  end
end
