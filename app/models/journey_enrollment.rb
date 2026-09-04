class JourneyEnrollment < ApplicationRecord
  STATES = %w[active waiting completed cancelled].freeze

  belongs_to :workspace
  belongs_to :journey
  belongs_to :person
  belongs_to :current_step, class_name: "JourneyStep", optional: true

  validates :state, inclusion: { in: STATES }

  scope :due, -> { where(state: %w[active waiting]).where("next_run_at IS NULL OR next_run_at <= ?", Time.current) }

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
