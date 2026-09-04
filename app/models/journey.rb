class Journey < ApplicationRecord
  ENTRY_TRIGGERS = %w[
    lead_form_submitted segment_entry lifecycle_changed email_clicked booking_created manual
  ].freeze

  belongs_to :workspace
  has_many :steps, class_name: "JourneyStep", dependent: :destroy, inverse_of: :journey
  has_many :enrollments, class_name: "JourneyEnrollment", dependent: :destroy

  validates :name, :entry_trigger, presence: true
  validates :entry_trigger, inclusion: { in: ENTRY_TRIGGERS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  accepts_nested_attributes_for :steps, allow_destroy: true, reject_if: :all_blank_step?

  before_validation :normalize_entry_config

  private

  def normalize_entry_config
    return unless entry_config.is_a?(Hash)

    self.entry_config = entry_config.stringify_keys.reject { |_key, value| value.blank? }
  end

  def all_blank_step?(attributes)
    attributes["step_type"].blank? && attributes["position"].blank?
  end
end
