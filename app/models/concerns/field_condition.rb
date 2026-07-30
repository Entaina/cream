# Shared field/operator/value condition logic for stage entry rules and alert rules.
module FieldCondition
  extend ActiveSupport::Concern

  DEAL_FIELDS = {
    "value" => "Valor",
    "probability" => "Probabilidad",
    "expected_close_date" => "Fecha de cierre",
    "name" => "Nombre",
    "invoice_number" => "Nº factura",
    "open" => "Abierto (no ganado ni perdido)"
  }.freeze

  COMPANY_FIELDS = {
    "company.name" => "Nombre",
    "company.domain" => "Dominio",
    "company.industry" => "Industria",
    "company.annual_revenue" => "Facturación anual",
    "company.employee_range" => "Tamaño",
    "company.location" => "Ubicación",
    "company.fiscal_information" => "Información fiscal"
  }.freeze

  PERSON_FIELDS = {
    "person.first_name" => "Nombre",
    "person.last_name" => "Apellidos",
    "person.email" => "Email",
    "person.phone" => "Teléfono",
    "person.job_title" => "Cargo",
    "person.source" => "Origen",
    "person.first_contact_on" => "Primer contacto"
  }.freeze

  OPERATORS = {
    "eq" => "es igual a",
    "neq" => "no es igual a",
    "lt" => "es menor que",
    "lte" => "es menor o igual que",
    "gt" => "es mayor que",
    "gte" => "es mayor o igual que",
    "contains" => "contiene",
    "blank" => "está vacío",
    "present" => "tiene valor"
  }.freeze

  FIELD_GROUPS = [
    { key: :deal, label: "Deal", prefix: nil, record_type: "Deal", natives: DEAL_FIELDS },
    { key: :deal_cf, label: "Campos adicionales del deal", prefix: "cf", record_type: "Deal", natives: {} },
    { key: :company, label: "Empresa", prefix: nil, record_type: "Company", natives: COMPANY_FIELDS },
    { key: :company_cf, label: "Campos adicionales de la empresa", prefix: "company.cf", record_type: "Company", natives: {} },
    { key: :person, label: "Contacto", prefix: nil, record_type: "Person", natives: PERSON_FIELDS },
    { key: :person_cf, label: "Campos adicionales del contacto", prefix: "person.cf", record_type: "Person", natives: {} }
  ].freeze

  included do
    validates :field, presence: true
    validates :operator, inclusion: { in: OPERATORS.keys }
    validates :compare_value, presence: true, unless: :blank_or_present_operator?
    validate :field_allowed_in_workspace

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:position, :id) }
  end

  class_methods do
    def allowed_field_keys(workspace)
      FIELD_GROUPS.flat_map { |group| field_keys_for_group(workspace, group) }
    end

    def field_options(workspace)
      FIELD_GROUPS.filter_map do |group|
        options = field_keys_for_group(workspace, group).map { |key| [ field_label_for(workspace, key), key ] }
        next if options.empty?

        [ group[:label], options ]
      end
    end

    def field_label_for(workspace, key)
      return DEAL_FIELDS[key] if DEAL_FIELDS.key?(key)
      return "#{COMPANY_FIELDS[key]} de la empresa" if COMPANY_FIELDS.key?(key)
      return "#{PERSON_FIELDS[key]} del contacto" if PERSON_FIELDS.key?(key)

      custom_field = resolve_custom_field(workspace, key)
      return key unless custom_field

      case custom_field.record_type
      when "Deal" then custom_field.name
      when "Company" then "#{custom_field.name} de la empresa"
      when "Person" then "#{custom_field.name} del contacto"
      else custom_field.name
      end
    end

    def field_keys_for_group(workspace, group)
      if group[:natives].present?
        group[:natives].keys
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
  end

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

  def describe = "#{field_label} #{OPERATORS[operator]}#{compare_suffix}"

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
      [ deal.custom_fields_hash[Regexp.last_match(1)] ]
    when /\Acompany\.cf:(.+)\z/
      [ deal.company&.custom_fields_hash&.[](Regexp.last_match(1)) ]
    when /\Aperson\.cf:(.+)\z/
      key = Regexp.last_match(1)
      deal.contacts.map { |person| person.custom_fields_hash[key] }
    when /\Acompany\.(.+)\z/
      [ deal.company&.public_send(Regexp.last_match(1)) ]
    when /\Aperson\.(.+)\z/
      attr = Regexp.last_match(1)
      deal.contacts.map { |person| person.public_send(attr) }
    else
      [ deal.public_send(field) ]
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
    custom_field_definition&.field_type == "date" ? custom_field_definition.cast(compare_value) : Date.parse(compare_value.to_s)
  end

  def cast_compare_value_as_decimal
    custom_field_definition&.field_type.in?(%w[number currency]) ?
      custom_field_definition.cast(compare_value) : compare_value.to_d
  end

  def date_field?
    field == "expected_close_date" || field == "person.first_contact_on" ||
      custom_field_definition&.field_type == "date"
  end

  def numeric_field?
    field.in?(%w[value probability company.annual_revenue]) ||
      custom_field_definition&.field_type.in?(%w[number currency])
  end

  def field_allowed_in_workspace
    return if field.blank? || workspace.nil?
    return if self.class.allowed_field_keys(workspace).include?(field)

    errors.add(:field, "is not available in this workspace")
  end
end
