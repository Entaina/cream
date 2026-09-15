# Workspace-defined custom attributes on CRM records.
module CustomFields
  extend ActiveSupport::Concern

  included do
    has_many :custom_field_values, as: :record, dependent: :destroy

    validate :validate_required_custom_fields, if: :custom_fields_input?
    after_save :persist_custom_fields, if: :custom_fields_input?
    after_destroy :cleanup_reference_values
  end

  class_methods do
    # Narrow a relation to records matching the given custom field filters.
    # `filters` is a hash of { field_key => raw_value }; blanks and unknown keys are ignored.
    def apply_custom_field_filters(workspace, filters)
      scope = all
      return scope if workspace.nil? || filters.blank?

      filters = filters.to_unsafe_h if filters.respond_to?(:to_unsafe_h)
      filters.to_h.each do |key, raw|
        next if raw.blank?

        field = workspace.custom_fields.find_by(record_type: name, key: key)
        next unless field

        matches = CustomFieldValue.where(custom_field_id: field.id, record_type: name)
        matches =
          if field.multi?
            matches.where("value @> ?::jsonb", [raw].to_json)
          else
            matches.where("value = ?::jsonb", field.cast(raw).to_json)
          end
        scope = scope.where(id: matches.select(:record_id))
      end

      scope
    end

    # Order a relation by a custom field value, with missing values sorted last.
    def sorted_by_custom_field(workspace, key, direction)
      return all if workspace.nil?

      field = workspace.custom_fields.find_by(record_type: name, key: key)
      return all unless field

      join = sanitize_sql_array([
        "LEFT JOIN custom_field_values cfv ON cfv.record_type = ? " \
        "AND cfv.record_id = #{table_name}.id AND cfv.custom_field_id = ?",
        name, field.id
      ])
      dir = (direction.to_s == "desc") ? "DESC" : "ASC"
      joins(join).order(Arel.sql("cfv.value #{dir} NULLS LAST"))
    end
  end

  def custom_field_definitions
    return CustomField.none unless workspace

    workspace.custom_fields.where(record_type: self.class.name).ordered
  end

  def custom_fields_hash
    values_by_field_id = custom_field_values.index_by(&:custom_field_id)
    custom_field_definitions.each_with_object({}) do |field, hash|
      hash[field.key] = if field.formula? && CreamFeatures.enabled?(:formula_fields)
        FormulaEvaluator.evaluate(field.formula_expression, record: self)
      elsif field.formula?
        nil
      else
        values_by_field_id[field.id]&.typed_value
      end
    end
  end

  def custom_fields
    custom_fields_hash
  end

  def custom_fields=(hash)
    @custom_fields_input = if hash.nil?
      {}
    elsif hash.respond_to?(:to_unsafe_h)
      hash.to_unsafe_h.stringify_keys
    else
      hash.to_h.stringify_keys
    end

    # Ensure save runs callbacks when only custom fields change.
    self.updated_at = Time.current if persisted?
  end

  private

  def custom_fields_input?
    !@custom_fields_input.nil?
  end

  def validate_required_custom_fields
    custom_field_definitions.where(required: true).find_each do |field|
      next unless @custom_fields_input.key?(field.key)

      if field.boolean?
        errors.add(:base, "#{field.name} is required") unless @custom_fields_input.key?(field.key)
        next
      end

      cast = field.cast(@custom_fields_input[field.key])
      blank = cast.nil? || (cast.is_a?(String) && cast.blank?) || (cast.is_a?(Array) && cast.empty?)
      errors.add(:base, "#{field.name} is required") if blank
    end
  end

  def persist_custom_fields
    changes = {}

    custom_field_definitions.where(key: @custom_fields_input.keys).find_each do |field|
      raw = @custom_fields_input[field.key]
      cast = field.cast(raw)
      existing = custom_field_values.find_by(custom_field: field)
      stored = serialize_custom_value(field, cast)

      if stored.nil?
        if existing
          changes[field.name] = [existing.typed_value.to_s, ""]
          existing.destroy!
        end
        next
      end

      if existing
        old_display = existing.typed_value.to_s
        if existing.value != stored
          existing.update!(value: stored)
          changes[field.name] = [old_display, cast.to_s]
        end
      else
        custom_field_values.create!(custom_field: field, workspace: workspace, value: stored)
        changes[field.name] = ["", cast.to_s]
      end
    end

    track_activity("updated", metadata: {changes: changes.transform_values { |(from, to)| [from, to] }}) if changes.any?
    @custom_fields_input = nil
  end

  def serialize_custom_value(field, cast)
    return nil if cast.nil?
    return nil if cast.is_a?(String) && cast.blank?
    return nil if cast.is_a?(Array) && cast.empty?

    case field.field_type
    when "date" then cast.to_s
    when "number", "currency" then cast.to_s
    when "boolean" then cast
    when "multi_select" then cast
    when "record_reference" then cast
    else cast
    end
  end

  def cleanup_reference_values
    return unless workspace_id

    field_ids = workspace.custom_fields.where(field_type: "record_reference", reference_type: self.class.name).pluck(:id)
    return if field_ids.empty?

    CustomFieldValue.where(custom_field_id: field_ids).where("value = ?::jsonb", id.to_json).destroy_all
  end
end
