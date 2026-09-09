module LeadFormTemplates
  class HtmlSchema
    LEAD_NAME_PATTERN = /\Alead\[([a-z][a-z0-9_]{0,39})\]\z/
    SKIPPED_REQUIRED_VALIDATION = (LeadForm::METADATA_FIELDS + %w[product_id]).freeze

    Field = Data.define(
      :name,
      :input_type,
      :required,
      :allowed_values,
      :checkbox_value,
      :requires_collects_company,
      :requires_open_editions,
      :requires_product,
      :dynamic_allowed_values
    )

    def self.parse(html)
      new(html: html)
    end

    def self.from_stored(data)
      fields = Array(data["fields"]).map { |attrs| field_from_hash(attrs) }
      new(fields: fields)
    end

    def self.field_from_hash(attrs)
      Field.new(
        name: attrs.fetch("name"),
        input_type: attrs.fetch("input_type"),
        required: attrs.fetch("required"),
        allowed_values: attrs["allowed_values"],
        checkbox_value: attrs.fetch("checkbox_value", "1"),
        requires_collects_company: attrs.fetch("requires_collects_company", false),
        requires_open_editions: attrs.fetch("requires_open_editions", false),
        requires_product: attrs.fetch("requires_product", false),
        dynamic_allowed_values: attrs["dynamic_allowed_values"]
      )
    end

    def initialize(html: nil, fields: nil)
      @fields = fields || build_fields(html)
    end

    attr_reader :fields

    def allowed_param_keys
      system_keys = @workspace ? LeadForm.system_field_keys_for(@workspace) : LeadForm::SYSTEM_FIELD_KEYS
      (fields.map(&:name) + system_keys).uniq
    end

    def apply_context(lead_form:, product:, open_editions:)
      contextual_fields = fields.filter_map do |field|
        next unless field_active?(field, lead_form:, product:, open_editions:)

        apply_dynamic_values(field, product:, open_editions:)
      end

      contextual_fields.concat(admin_hidden_fields(lead_form.hidden_field_keys))

      schema = self.class.new(fields: contextual_fields)
      schema.instance_variable_set(:@workspace, lead_form.workspace)
      schema
    end

    def validate!(params)
      person = Person.new
      errors = person.errors
      params = params.stringify_keys

      unknown_keys(params).each do |key|
        errors.add(:base, "Unknown field #{key}")
      end

      fields.each do |field|
        value = params[field.name]
        validate_field!(errors, field, value)
      end

      raise ActiveRecord::RecordInvalid.new(person) if errors.any?

      person
    end

    private

    def unknown_keys(params)
      params.keys - allowed_param_keys
    end

    def field_active?(field, lead_form:, product:, open_editions:)
      return false if field.requires_collects_company && !lead_form.collects_company?
      return false if field.requires_open_editions && open_editions.blank?
      return false if field.requires_product && product.nil?

      true
    end

    def apply_dynamic_values(field, product:, open_editions:)
      return field unless field.dynamic_allowed_values == "open_editions"

      field.with(allowed_values: open_editions.map { |edition| edition.id.to_s })
    end

    def admin_hidden_fields(keys)
      Array(keys).filter_map do |key|
        next unless LeadForm.field_key?(key)
        next if fields.any? { |field| field.name == key }

        Field.new(
          name: key,
          input_type: "hidden",
          required: false,
          allowed_values: nil,
          checkbox_value: "1",
          requires_collects_company: false,
          requires_open_editions: false,
          requires_product: false,
          dynamic_allowed_values: nil
        )
      end
    end

    def build_fields(html)
      controls_by_name = Hash.new { |hash, key| hash[key] = [] }

      Nokogiri::HTML.fragment(html).css("input, select, textarea").each do |node|
        match = node["name"]&.match(LEAD_NAME_PATTERN)
        next unless match

        controls_by_name[match[1]] << node
      end

      controls_by_name.map do |name, nodes|
        build_field(name, nodes)
      end
    end

    def build_field(name, nodes)
      input_type = infer_input_type(nodes)
      required = required_field?(name, nodes)
      allowed_values = extract_allowed_values(nodes, input_type)
      checkbox_value = nodes.find { |node| node["type"] == "checkbox" }&.[]("value") || "1"

      Field.new(
        name: name,
        input_type: input_type,
        required: required,
        allowed_values: allowed_values,
        checkbox_value: checkbox_value,
        requires_collects_company: false,
        requires_open_editions: false,
        requires_product: false,
        dynamic_allowed_values: nil
      )
    end

    def infer_input_type(nodes)
      return "select" if nodes.any? { |node| node.name == "select" }
      return "textarea" if nodes.any? { |node| node.name == "textarea" }
      return "checkbox" if nodes.any? { |node| node["type"] == "checkbox" }
      return "radio" if nodes.any? { |node| node["type"] == "radio" }

      visible_input = nodes.find { |node| node.name == "input" && node["type"] != "hidden" }
      visible_input&.[]("type").presence || nodes.first&.[]("type") || "text"
    end

    def required_field?(name, nodes)
      return false if SKIPPED_REQUIRED_VALIDATION.include?(name)

      nodes.any? { |node| node["required"].present? }
    end

    def extract_allowed_values(nodes, input_type)
      case input_type
      when "select"
        nodes.flat_map do |node|
          node.css("option").filter_map { |option| option["value"].presence }
        end.uniq
      when "radio"
        nodes.filter_map { |node| node["value"].presence }.uniq
      when "checkbox"
        hidden = nodes.find { |node| node["type"] == "hidden" }&.[]("value")
        checked = nodes.find { |node| node["type"] == "checkbox" }&.[]("value") || "1"
        [ hidden, checked ].compact_blank.uniq.presence
      end
    end

    def validate_field!(errors, field, value)
      if field.required
        if field.input_type == "checkbox"
          errors.add(error_attribute(field.name), "must be accepted") unless value.to_s == field.checkbox_value
        elsif value.blank?
          errors.add(error_attribute(field.name), "can't be blank")
        end
      end

      return if value.blank?

      if field.input_type == "email" && !value.to_s.match?(URI::MailTo::EMAIL_REGEXP)
        errors.add(error_attribute(field.name), "is invalid")
      end

      if field.allowed_values.present? && !field.allowed_values.include?(value.to_s)
        errors.add(error_attribute(field.name), "#{field.name.tr('_', ' ')} is invalid")
      end
    end

    def error_attribute(name)
      Person.attribute_names.include?(name) ? name.to_sym : :base
    end
  end
end
