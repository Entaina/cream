# Auto-computed metrics inspired by Streak "magic columns".
module MagicColumns
  extend ActiveSupport::Concern

  MAGIC_COLUMNS = {
    days_in_stage: {label: "Days in stage", types: %w[Deal]},
    last_activity_at: {label: "Last activity", types: %w[Person Company Deal]},
    notes_count: {label: "Notes", types: %w[Person Company Deal]},
    tasks_count: {label: "Tasks", types: %w[Person Company Deal]},
    open_tasks_count: {label: "Open tasks", types: %w[Person Company Deal]}
  }.freeze

  def magic_column_value(key)
    case key.to_sym
    when :days_in_stage
      days_in_stage_value
    when :last_activity_at
      last_activity_at_value
    when :notes_count
      notes.count
    when :tasks_count
      tasks.count
    when :open_tasks_count
      tasks.pending.count
    end
  end

  def self.available_for(record_type)
    MAGIC_COLUMNS.select { |_key, meta| meta[:types].include?(record_type) }
  end

  private

  def days_in_stage_value
    return nil unless is_a?(Deal)

    stage_change = activities.where(action: "stage_changed").recent_first.first
    reference = stage_change&.created_at || updated_at
    ((Time.current - reference) / 1.day).floor
  end

  def last_activity_at_value
    activities.recent_first.pick(:created_at)
  end
end
