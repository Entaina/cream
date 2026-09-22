class SlackIntegration < ApplicationRecord
  NOTIFY_EVENTS = %w[deal.stage_changed mention task_overdue email_opened].freeze

  belongs_to :workspace

  validates :webhook_url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}
  validate :notify_events_allowed

  scope :active, -> { where(active: true) }

  private

  def notify_events_allowed
    invalid = Array(notify_events) - NOTIFY_EVENTS
    return if invalid.empty?

    errors.add(:notify_events, :contain_invalid_values, values: invalid.join(", "))
  end
end
