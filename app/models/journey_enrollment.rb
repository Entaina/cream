class JourneyEnrollment < ApplicationRecord
  include WorkspaceScopedAssociations

  STATES = %w[active waiting completed cancelled].freeze
  HISTORY_PREVIEW = 5
  HISTORY_LIMIT = 100

  belongs_to :workspace
  belongs_to :journey
  belongs_to :person
  belongs_to :current_step, class_name: "JourneyStep", optional: true

  validates :state, inclusion: {in: STATES}
  validates_same_workspace :journey, :person
  validate :current_step_in_journey, if: -> { current_step.present? }

  scope :due, -> { where(state: %w[active waiting]).where("next_run_at IS NULL OR next_run_at <= ?", Time.current) }
  scope :in_progress, -> { where(state: %w[active waiting]) }

  def current_step_in_journey
    return unless new_record? || will_save_change_to_current_step_id? || will_save_change_to_journey_id?
    return if journey.nil? || current_step.journey_id == journey_id

    errors.add(:current_step, :must_belong_to_same_workspace)
  end

  def in_progress?
    state.in?(%w[active waiting])
  end

  def advance_to!(step, wait_until: nil)
    update!(
      current_step: step,
      state: wait_until ? "waiting" : "active",
      next_run_at: wait_until
    )
  end

  def complete!
    update!(state: "completed", current_step: nil, next_run_at: nil)
  end
end
