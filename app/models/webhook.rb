class Webhook < ApplicationRecord
  EVENTS = %w[
    record.created record.updated deal.stage_changed
    comment.created task.completed email.opened
  ].freeze

  belongs_to :workspace
  belongs_to :user
  has_many :webhook_deliveries, dependent: :destroy

  validates :url, presence: true, format: {with: URI::DEFAULT_PARSER.make_regexp(%w[http https])}
  validate :events_allowed

  scope :active, -> { where(active: true) }

  private

  def events_allowed
    invalid = Array(events) - EVENTS
    return if invalid.empty?

    errors.add(:events, :contain_invalid_values, values: invalid.join(", "))
  end
end
