class CustomField < ApplicationRecord
  FIELD_TYPES = %w[text long_text number currency date boolean select multi_select url email formula record_reference].freeze
  RECORD_TYPES = %w[Person Company Deal].freeze

  belongs_to :workspace
  has_many :custom_field_values, dependent: :destroy

  validates :name, :field_type, :record_type, :key, presence: true
  validates :field_type, inclusion: {in: FIELD_TYPES}
  validates :record_type, inclusion: {in: RECORD_TYPES}
  validates :key, uniqueness: {scope: %i[workspace_id record_type]}
  validate :options_present_for_select_types
  validate :formula_expression_present_for_formula
  validate :reference_type_present_for_record_reference

  before_validation :derive_key, on: :create
  before_validation :assign_position, on: :create

  scope :ordered, -> { order(:position, :id) }

  def select? = field_type.in?(%w[select multi_select])
  def multi? = field_type == "multi_select"
  def boolean? = field_type == "boolean"
  def formula? = field_type == "formula"
  def reference? = field_type == "record_reference"

  def reference_scope(workspace)
    return none_scope unless workspace && reference_type.in?(RECORD_TYPES)

    case reference_type
    when "Person"
      workspace.people.order(:first_name, :last_name)
    when "Company"
      workspace.companies.order(:name)
    when "Deal"
      workspace.deals.order(:name)
    end
  end

  def reference_label_method
    (reference_type == "Person") ? :display_name : :name
  end

  def cast(raw)
    case field_type
    when "text", "long_text", "url", "email", "select"
      raw.to_s.strip.presence
    when "number", "currency"
      return nil if raw.blank?

      BigDecimal(raw.to_s)
    when "date"
      return nil if raw.blank?

      Date.parse(raw.to_s)
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(raw)
    when "multi_select"
      Array(raw).map(&:to_s).map(&:strip).reject(&:blank?).presence
    when "record_reference"
      return nil if raw.blank?

      Integer(raw)
    end
  rescue ArgumentError, TypeError
    nil
  end

  def field_type_label
    I18n.t("integrations.custom_fields.field_types.#{field_type}", default: field_type.humanize)
  end

  def record_type_label
    I18n.t("integrations.custom_fields.record_types.#{record_type}", default: record_type)
  end

  private

  def derive_key
    return if name.blank?
    return if key.present? && !key_changed?

    base = name.parameterize(separator: "_")
    candidate = base
    suffix = 1
    scope = workspace.custom_fields.where(record_type: record_type)
    scope = scope.where.not(id: id) if persisted?
    while scope.exists?(key: candidate)
      candidate = "#{base}_#{suffix}"
      suffix += 1
    end
    self.key = candidate
  end

  def assign_position
    return if position.positive? || workspace.nil?

    self.position = (workspace.custom_fields.where(record_type: record_type).maximum(:position) || -1) + 1
  end

  def options_present_for_select_types
    return unless select?
    return if options.is_a?(Array) && options.any?

    errors.add(:options, "must include at least one option for select fields")
  end

  def formula_expression_present_for_formula
    return unless formula?
    return if formula_expression.present?

    errors.add(:formula_expression, "is required for formula fields")
  end

  def reference_type_present_for_record_reference
    return unless reference?
    return if reference_type.in?(RECORD_TYPES)

    errors.add(:reference_type, "must be Person, Company, or Deal for record reference fields")
  end

  def none_scope
    Person.none
  end
end
