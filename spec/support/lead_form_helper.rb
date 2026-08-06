module LeadFormHelper
  def create_email_template!(workspace, user:, **attrs)
    workspace.email_templates.create!({
      user: user,
      name: "Confirmación lead",
      subject: "Gracias {first_name}",
      body: "Hola {first_name}, gracias por contactar."
    }.merge(attrs))
  end

  def create_lead_form!(workspace, user:, pipeline: nil, **attrs)
    pipeline ||= Pipeline.default_for(workspace) || Pipeline.create_default!(workspace)
    template = if attrs.key?(:email_template)
      attrs.delete(:email_template)
    else
      create_email_template!(workspace, user: user)
    end
    workspace.lead_forms.create!({
      name: "Contacto web",
      slug: "contacto-#{SecureRandom.hex(3)}",
      template_key: "contacto",
      pipeline: pipeline,
      responsible: user,
      email_template: template,
      active: true,
      pipeline_routes: {}
    }.merge(attrs))
  end

  def contacto_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "help_type" => "curso",
      "how_heard" => "evento",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def trabajando_ia_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "how_heard" => "evento",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def desarrollando_ia_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "tech_profile" => "desarrollo",
      "audience" => "para_mi",
      "how_heard" => "evento",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def adoption_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "how_heard" => "evento",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def indice_adopcion_ia_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "company_name" => "Acme SL",
      "job_title" => "Directora de innovación",
      "employee_range" => "51-200",
      "how_heard" => "evento",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def liderando_ia_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "company_name" => "Acme SL",
      "audience" => "para_equipo",
      "how_heard" => "linkedin",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def liderando_ia_reserva_lead_params(overrides = {})
    product = overrides.delete(:product) || overrides.delete("product")
    edition = overrides.delete(:edition) || overrides.delete("edition")
    params = {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone" => "600111222",
      "message" => "Quiero reservar plaza",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }
    params["product_id"] = product.id.to_s if product
    params["edition_id"] = edition.id.to_s if edition
    params.merge(overrides.stringify_keys)
  end

  def desarrollando_ia_reserva_lead_params(overrides = {})
    product = overrides.delete(:product) || overrides.delete("product")
    edition = overrides.delete(:edition) || overrides.delete("edition")
    params = {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "phone_prefix" => "+34",
      "phone" => "600111222",
      "message" => "Quiero reservar plaza",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }
    params["product_id"] = product.id.to_s if product
    params["edition_id"] = edition.id.to_s if edition
    params.merge(overrides.stringify_keys)
  end

  def entrenadores_lead_params(overrides = {})
    {
      "email" => "lead@example.com",
      "first_name" => "Ana",
      "last_name" => "García",
      "gdpr_consent" => "1",
      LeadForm::TIMESTAMP_FIELD => valid_lead_form_timestamp
    }.merge(overrides.stringify_keys)
  end

  def valid_lead_form_timestamp
    LeadForm.signed_timestamp(at: 10.seconds.ago)
  end
end

RSpec.configure { |config| config.include LeadFormHelper }
