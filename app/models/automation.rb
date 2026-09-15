class Automation < ApplicationRecord
  TRIGGER_EVENTS = %w[deal.stage_changed record.created task.completed].freeze
  ACTION_TYPES = %w[create_task send_email notify_slack].freeze

  belongs_to :workspace

  validates :name, :trigger_event, :action_type, presence: true
  validates :trigger_event, inclusion: {in: TRIGGER_EVENTS}
  validates :action_type, inclusion: {in: ACTION_TYPES}

  scope :active, -> { where(active: true) }
  scope :for_event, ->(event) { active.where(trigger_event: event) }
end
