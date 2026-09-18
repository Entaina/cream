class AlertRule < ApplicationRecord
  TRIGGER_FIELDS = %w[edition_ends_on edition_starts_on deal_expected_close_date].freeze
  RECIPIENTS = %w[deal_owner admins].freeze

  belongs_to :workspace
  has_many :alert_conditions, dependent: :destroy
  has_many :alert_deliveries, dependent: :destroy

  accepts_nested_attributes_for :alert_conditions, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:field].blank? }

  validates :name, :trigger_field, :recipient, presence: true
  validates :trigger_field, inclusion: {in: TRIGGER_FIELDS}
  validates :recipient, inclusion: {in: RECIPIENTS}

  scope :active, -> { where(active: true) }

  def trigger_field_label
    self.class.trigger_field_label(trigger_field)
  end

  def recipient_label
    self.class.recipient_label(recipient)
  end

  def offset_summary
    return "" if offset_days.zero?

    " (#{I18n.t("alert_rules.index.days_offset", count: offset_days)})"
  end

  def active_conditions_summary
    active = alert_conditions.select(&:active?)
    return "" if active.empty?

    joiner = I18n.t("alert_rules.index.and")
    " #{joiner}#{active.map(&:describe).join(joiner)}"
  end

  def self.trigger_field_label(key)
    I18n.t(key, scope: "alert_rules.trigger_fields")
  end

  def self.recipient_label(key)
    I18n.t(key, scope: "alert_rules.recipients")
  end

  def self.trigger_field_options
    TRIGGER_FIELDS.map { |key| [trigger_field_label(key), key] }
  end

  def self.recipient_options
    RECIPIENTS.map { |key| [recipient_label(key), key] }
  end
end
