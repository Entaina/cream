class JourneyStep < ApplicationRecord
  STEP_TYPES = %w[send_email wait branch set_field add_to_segment create_task adjust_score notify].freeze

  belongs_to :journey, inverse_of: :steps
  has_many :enrollments, class_name: "JourneyEnrollment", foreign_key: :current_step_id, dependent: :nullify, inverse_of: :current_step

  validates :step_type, inclusion: { in: STEP_TYPES }
  validates :position, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def next_step
    journey.steps.active.where("position > ?", position).ordered.first
  end
end
