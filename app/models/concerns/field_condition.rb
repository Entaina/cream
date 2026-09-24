# Shared field/operator/value condition logic for stage entry rules and alert rules.
module FieldCondition
  extend ActiveSupport::Concern

  DEAL_FIELD_KEYS = %w[value probability expected_close_date execution_duration_days name invoice_number open].freeze

  COMPANY_FIELD_KEYS = {
    "company.name" => :name,
    "company.domain" => :domain,
    "company.industry" => :industry,
    "company.annual_revenue" => :annual_revenue,
    "company.employee_range" => :employee_range,
    "company.location" => :location,
    "company.fiscal_information" => :fiscal_information
  }.freeze

  PERSON_FIELD_KEYS = {
    "person.first_name" => :first_name,
    "person.last_name" => :last_name,
    "person.email" => :email,
    "person.phone" => :phone,
    "person.job_title" => :job_title,
    "person.source" => :source,
    "person.first_contact_on" => :first_contact_on
  }.freeze

  OPERATORS = %w[eq neq lt lte gt gte contains blank present].freeze

  FIELD_GROUPS = [
    {key: :deal, prefix: nil, record_type: "Deal", natives: DEAL_FIELD_KEYS},
    {key: :deal_cf, prefix: "cf", record_type: "Deal", natives: nil},
    {key: :company, prefix: nil, record_type: "Company", natives: COMPANY_FIELD_KEYS.keys},
    {key: :company_cf, prefix: "company.cf", record_type: "Company", natives: nil},
    {key: :person, prefix: nil, record_type: "Person", natives: PERSON_FIELD_KEYS.keys},
    {key: :person_cf, prefix: "person.cf", record_type: "Person", natives: nil}
  ].freeze

  included do
    validates :field, presence: true
    validates :operator, inclusion: {in: OPERATORS}
    validates :compare_value, presence: true, unless: :blank_or_present_operator?
    validate :field_allowed_in_workspace

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :id) }
  end

  module ClassMethods
    def allowed_field_keys(workspace)
      FIELD_GROUPS.flat_map { |group| field_keys_for_group(workspace, group) }
    end

    def field_options(workspace)
      FIELD_GROUPS.filter_map do |group|
        options = field_keys_for_group(workspace, group).map { |key| [field_label_for(workspace, key), key] }
        next if options.empty?

        [group_label(group[:key]), options]
      end
    end

    def group_label(group_key)
      I18n.t(group_key, scope: "field_conditions.groups")
    end

    def operator_label(operator)
      I18n.t(operator, scope: "field_conditions.operators")
    end

    def requirement_operator_label(operator)
      I18n.t(operator, scope: "field_conditions.requirement_operators")
    end

    def operator_options
      OPERATORS.map { |key| [operator_label(key), key] }
    end

    def operator_labels
      OPERATORS.index_with { |operator| operator_label(operator) }
    end

    def field_label_for(workspace, key)
      if DEAL_FIELD_KEYS.include?(key)
        return I18n.t("field_conditions.deal_fields.open") if key == "open"

        return I18n.t("activerecord.attributes.deal.#{key}")
      end

      if (attr = COMPANY_FIELD_KEYS[key])
        label = I18n.t("activerecord.attributes.company.#{attr}")
        return I18n.t("field_conditions.company_field", field: label)
      end

      if (attr = PERSON_FIELD_KEYS[key])
        label = person_native_label(attr)
        return I18n.t("field_conditions.person_field", field: label)
      end

      custom_field = resolve_custom_field(workspace, key)
      return key unless custom_field

      case custom_field.record_type
      when "Deal" then custom_field.name
      when "Company" then I18n.t("field_conditions.company_field", field: custom_field.name)
      when "Person" then I18n.t("field_conditions.person_field", field: custom_field.name)
      else custom_field.name
      end
    end

    def field_keys_for_group(workspace, group)
      if group[:natives]
        group[:natives]
      else
        prefix = group[:prefix]
        workspace.custom_fields.where(record_type: group[:record_type]).ordered.pluck(:key)
          .map { |key| "#{prefix}:#{key}" }
      end
    end

    def resolve_custom_field(workspace, key)
      case key
      when /\Acf:(.+)\z/
        workspace.custom_fields.find_by(record_type: "Deal", key: Regexp.last_match(1))
      when /\Acompany\.cf:(.+)\z/
        workspace.custom_fields.find_by(record_type: "Company", key: Regexp.last_match(1))
      when /\Aperson\.cf:(.+)\z/
        workspace.custom_fields.find_by(record_type: "Person", key: Regexp.last_match(1))
      end
    end

    def person_native_label(attr)
      if attr.in?(%i[email source first_contact_on])
        I18n.t(attr, scope: "field_conditions.person_fields")
      else
        I18n.t("activerecord.attributes.person.#{attr}")
      end
    end
  end

  extend ClassMethods

  def met?(deal)
    values = raw_values(deal)
    case operator
    when "blank"
      person_field? ? values.none? { |value| value_present?(value) } : !value_present?(values.first)
    when "present"
      person_field? ? values.any? { |value| value_present?(value) } : value_present?(values.first)
    else
      person_field? ? values.any? { |value| matches_value?(value) } : matches_value?(values.first)
    end
  end

  def describe = "#{field_label} #{self.class.operator_label(operator)}#{compare_suffix}"

  def describe_requirement = "#{field_label} #{self.class.requirement_operator_label(operator)}#{compare_suffix}"

  def field_label = self.class.field_label_for(workspace, field)

  def blank_or_present_operator? = operator.in?(%w[blank present])

  def person_field? = field.start_with?("person.")

  private

  def compare_suffix
    blank_or_present_operator? ? "" : " #{compare_value}"
  end

  def raw_values(deal)
    case field
    when /\Acf:(.+)\z/
      [deal.custom_fields_hash[Regexp.last_match(1)]]
    when /\Acompany\.cf:(.+)\z/
      [deal.company&.custom_fields_hash&.[](Regexp.last_match(1))]
    when /\Aperson\.cf:(.+)\z/
      key = Regexp.last_match(1)
      deal.contacts.map { |person| person.custom_fields_hash[key] }
    when /\Acompany\.(.+)\z/
      [deal.company&.public_send(Regexp.last_match(1))]
    when /\Aperson\.(.+)\z/
      attr = Regexp.last_match(1)
      deal.contacts.map { |person| person.public_send(attr) }
    else
      [deal.public_send(field)]
    end
  end

  def custom_field_definition
    @custom_field_definition ||= self.class.resolve_custom_field(workspace, field)
  end

  def value_present?(value)
    return false if value.nil?
    return false if value.is_a?(String) && value.blank?
    return false if value.is_a?(Array) && value.empty?

    true
  end

  def matches_value?(raw)
    if boolean_field?
      actual = ActiveModel::Type::Boolean.new.cast(raw)
      expected = ActiveModel::Type::Boolean.new.cast(compare_value)
      case operator
      when "eq" then actual == expected
      when "neq" then actual != expected
      else false
      end
    else
      case operator
      when "eq" then compare(raw) == 0
      when "neq" then !compare(raw).nil? && compare(raw) != 0
      when "lt" then compare(raw)&.negative?
      when "lte" then !compare(raw).nil? && compare(raw) <= 0
      when "gt" then compare(raw)&.positive?
      when "gte" then !compare(raw).nil? && compare(raw) >= 0
      when "contains" then raw.to_s.downcase.include?(compare_value.to_s.downcase)
      else false
      end
    end
  end

  def boolean_field?
    field == "open" || custom_field_definition&.boolean?
  end

  def compare(raw)
    return nil if raw.nil? || compare_value.nil?

    if date_field?
      raw.to_date <=> cast_compare_value_as_date
    elsif numeric_field?
      raw.to_d <=> cast_compare_value_as_decimal
    else
      normalized(raw) <=> normalized(cast_compare_value)
    end
  rescue ArgumentError, TypeError
    nil
  end

  def normalized(value)
    case value
    when Date, Time, DateTime then value.to_date
    when BigDecimal then value.to_d
    else value.to_s.strip.downcase
    end
  end

  def cast_compare_value
    custom_field_definition ? custom_field_definition.cast(compare_value) : compare_value
  end

  def cast_compare_value_as_date
    (custom_field_definition&.field_type == "date") ? custom_field_definition.cast(compare_value) : Date.parse(compare_value.to_s)
  end

  def cast_compare_value_as_decimal
    custom_field_definition&.field_type&.in?(%w[number currency]) ?
      custom_field_definition.cast(compare_value) : compare_value.to_d
  end

  def date_field?
    field == "expected_close_date" || field == "person.first_contact_on" ||
      custom_field_definition&.field_type == "date"
  end

  def numeric_field?
    field.in?(%w[value probability execution_duration_days company.annual_revenue]) ||
      custom_field_definition&.field_type&.in?(%w[number currency])
  end

  def field_allowed_in_workspace
    return if field.blank? || workspace.nil?
    return if self.class.allowed_field_keys(workspace).include?(field)

    errors.add(:field, :field_not_in_workspace)
  end
end
