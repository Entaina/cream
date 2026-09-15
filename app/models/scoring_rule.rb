class ScoringRule < ApplicationRecord
  EVENT_TYPES = %w[email_opened email_clicked email_sent page_view lead_submission booking_created deal_created form_field].freeze

  belongs_to :workspace

  validates :name, presence: true
  validates :points, numericality: {only_integer: true}
  validates :event_type, inclusion: {in: EVENT_TYPES}, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  def matches_event?(event, person:, metadata: {})
    return false unless active?
    return false if event_type.present? && event_type != event

    Array(conditions).all? do |condition|
      Marketing::ConditionEvaluator.new(condition).met_for_person?(person, metadata: metadata)
    end
  end
end
