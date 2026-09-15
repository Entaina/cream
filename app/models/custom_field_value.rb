class CustomFieldValue < ApplicationRecord
  belongs_to :custom_field
  belongs_to :workspace
  belongs_to :record, polymorphic: true

  validates :custom_field_id, uniqueness: {scope: %i[record_type record_id]}

  def typed_value
    raw = value
    return nil if raw.nil?

    case custom_field.field_type
    when "date"
      raw.is_a?(String) ? Date.parse(raw) : raw
    when "number", "currency"
      raw.is_a?(String) ? BigDecimal(raw) : raw
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(raw)
    when "multi_select"
      Array(raw)
    when "record_reference"
      raw.is_a?(Integer) ? raw : Integer(raw)
    else
      raw
    end
  rescue ArgumentError, TypeError
    nil
  end

  def blank_value?
    typed = typed_value
    typed.nil? || (typed.is_a?(String) && typed.blank?) || (typed.is_a?(Array) && typed.empty?)
  end
end
