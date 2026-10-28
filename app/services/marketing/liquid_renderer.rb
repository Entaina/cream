module Marketing
  class LiquidRenderer
    def self.render(text, record:, extra_tokens: {}, escape_html: false)
      template = Liquid::Template.parse(text.to_s, environment: LeadFormTemplates::Renderer.build_environment)
      assigns = assigns_for(record, extra_tokens)
      assigns = assigns.transform_values { |value| value.is_a?(String) ? ERB::Util.html_escape(value).to_str : value } if escape_html
      template.render!(assigns).to_s
    rescue Liquid::Error
      text.to_s
    end

    def self.assigns_for(record, extra_tokens)
      base = {
        "first_name" => record.try(:first_name).to_s,
        "last_name" => record.try(:last_name).to_s,
        "name" => record.try(:display_name).to_s,
        "email" => record.try(:email).to_s,
        "company" => record.try(:company)&.name.to_s
      }
      base.merge(extra_tokens.stringify_keys)
    end
    private_class_method :assigns_for
  end
end
