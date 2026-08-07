module LeadFormTemplateHelper
  SUBMISSION_SCHEMA_TYPE_COLORS = {
    "text" => "chicago",
    "email" => "golden",
    "tel" => "hoki",
    "textarea" => "copperfield",
    "select" => "hoki",
    "checkbox" => "copperfield",
    "radio" => "hoki",
    "hidden" => "chicago"
  }.freeze

  SUBMISSION_SCHEMA_TYPE_LABELS = {
    "text" => "Texto",
    "email" => "Email",
    "tel" => "Teléfono",
    "textarea" => "Texto largo",
    "select" => "Select",
    "checkbox" => "Checkbox",
    "radio" => "Radio",
    "hidden" => "Oculto"
  }.freeze

  def submission_schema_fields(template)
    Array(template.submission_schema["fields"])
  end

  def submission_schema_user_fields(template)
    system_keys = LeadForm::METADATA_FIELDS + [ LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD ]
    submission_schema_fields(template).reject { |field| system_keys.include?(field["name"]) }
  end

  def submission_schema_system_fields(template)
    system_keys = LeadForm::METADATA_FIELDS + [ LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD ]
    submission_schema_fields(template).select { |field| system_keys.include?(field["name"]) }
  end

  def submission_schema_field_type_label(input_type)
    SUBMISSION_SCHEMA_TYPE_LABELS.fetch(input_type.to_s, input_type.to_s.humanize)
  end

  def submission_schema_field_type_color(input_type)
    SUBMISSION_SCHEMA_TYPE_COLORS.fetch(input_type.to_s, "chicago")
  end

  def submission_schema_conditions(field)
    [].tap do |conditions|
      conditions << "Recoger empresa" if field["requires_collects_company"]
      conditions << "Producto configurado" if field["requires_product"]
      conditions << "Ediciones abiertas" if field["requires_open_editions"]
    end
  end

  def submission_schema_allowed_values_summary(field)
    if field["dynamic_allowed_values"] == "open_editions"
      return "IDs de ediciones abiertas (en runtime)"
    end

    values = Array(field["allowed_values"]).compact_blank
    return "—" if values.empty?

    if values.size <= 4
      values.join(", ")
    else
      "#{values.first(3).join(", ")} +#{values.size - 3} más"
    end
  end

  def lead_form_template_preview_button(template, **html_options)
    return unless template.previewable?

    defaults = {
      class: "btn-secondary",
      formmethod: :post,
      formaction: preview_lead_form_template_path(template),
      formtarget: "_blank",
      rel: "noopener noreferrer"
    }
    button_tag("Vista previa", **defaults.merge(html_options))
  end
end
