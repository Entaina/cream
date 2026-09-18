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

  def submission_schema_fields(template)
    Array(template.submission_schema["fields"])
  end

  def submission_schema_user_fields(template)
    system_keys = LeadForm::METADATA_FIELDS + [LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD]
    submission_schema_fields(template).reject { |field| system_keys.include?(field["name"]) }
  end

  def submission_schema_system_fields(template)
    system_keys = LeadForm::METADATA_FIELDS + [LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD]
    submission_schema_fields(template).select { |field| system_keys.include?(field["name"]) }
  end

  def submission_schema_field_type_label(input_type)
    t("marketing.lead_form_templates.schema_types.#{input_type}", default: input_type.to_s.humanize)
  end

  def submission_schema_field_type_color(input_type)
    SUBMISSION_SCHEMA_TYPE_COLORS.fetch(input_type.to_s, "chicago")
  end

  def submission_schema_conditions(field)
    [].tap do |conditions|
      conditions << t("marketing.lead_form_templates.schema_conditions.collects_company") if field["requires_collects_company"]
      conditions << t("marketing.lead_form_templates.schema_conditions.requires_product") if field["requires_product"]
      conditions << t("marketing.lead_form_templates.schema_conditions.open_editions") if field["requires_open_editions"]
    end
  end

  def submission_schema_allowed_values_summary(field)
    if field["dynamic_allowed_values"] == "open_editions"
      return t("marketing.lead_form_templates.schema_values.open_editions_dynamic")
    end

    values = Array(field["allowed_values"]).compact_blank
    return t("marketing.shared.em_dash") if values.empty?

    if values.size <= 4
      values.join(", ")
    else
      "#{values.first(3).join(", ")} #{t("marketing.lead_form_templates.schema_values.more", count: values.size - 3)}"
    end
  end
end
