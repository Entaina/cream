class AlertRule < ApplicationRecord
  TRIGGER_FIELDS = %w[edition_ends_on edition_starts_on deal_expected_close_date].freeze
  CONDITIONS = %w[company_without_fiscal_info deal_open].freeze
  RECIPIENTS = %w[deal_owner admins].freeze

  TRIGGER_FIELD_LABELS = {
    "edition_ends_on" => "Fin de edición",
    "edition_starts_on" => "Inicio de edición",
    "deal_expected_close_date" => "Fecha de cierre esperada del deal"
  }.freeze

  CONDITION_LABELS = {
    "company_without_fiscal_info" => "La empresa no tiene información fiscal",
    "deal_open" => "El deal está abierto (no ganado ni perdido)"
  }.freeze

  RECIPIENT_LABELS = {
    "deal_owner" => "Owner del deal",
    "admins" => "Administradores del workspace"
  }.freeze

  belongs_to :workspace
  has_many :alert_deliveries, dependent: :destroy

  validates :name, :trigger_field, :recipient, presence: true
  validates :trigger_field, inclusion: { in: TRIGGER_FIELDS }
  validates :recipient, inclusion: { in: RECIPIENTS }
  validate :conditions_are_valid

  scope :active, -> { where(active: true) }

  def trigger_field_label
    TRIGGER_FIELD_LABELS.fetch(trigger_field, trigger_field)
  end

  def recipient_label
    RECIPIENT_LABELS.fetch(recipient, recipient)
  end

  def condition_labels
    Array(conditions).map { |key| CONDITION_LABELS.fetch(key, key) }
  end

  private

  def conditions_are_valid
    invalid = Array(conditions).map(&:to_s) - CONDITIONS
    errors.add(:conditions, "contiene claves no válidas: #{invalid.join(', ')}") if invalid.any?
  end
end
