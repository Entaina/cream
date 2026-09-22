class Journey < ApplicationRecord
  ENTRY_TRIGGERS = %w[
    lead_form_submitted segment_entry lifecycle_changed email_clicked booking_created manual
  ].freeze

  belongs_to :workspace
  belongs_to :product, optional: true
  has_many :steps, class_name: "JourneyStep", dependent: :destroy, inverse_of: :journey
  has_many :enrollments, class_name: "JourneyEnrollment", dependent: :destroy
  has_many :campaign_sends, dependent: :nullify

  validates :name, :entry_trigger, presence: true
  validates :entry_trigger, inclusion: {in: ENTRY_TRIGGERS}
  validate :product_required_when_stop_on_open_deal
  validate :product_belongs_to_workspace

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

  def product_required_when_stop_on_open_deal
    return unless stop_on_open_deal?

    errors.add(:product, :product_required_stop_open_deal) if product_id.blank?
  end

  def product_belongs_to_workspace
    return if product.nil? || workspace.nil?

    errors.add(:product, :must_belong_to_workspace) if product.workspace_id != workspace_id
  end
end
