module LeadFormHelper
  def create_email_template!(workspace, user:, **attrs)
    workspace.email_templates.create!({
      user: user,
      name: "Confirmación lead",
      subject: "Gracias {first_name}",
      body: "Hola {first_name}, gracias por contactar."
    }.merge(attrs))
  end

  def import_lead_form_templates!(workspace)
    LeadFormTemplates::Importer.import!(workspace)
  end

  # Las plantillas por defecto no pintan la casilla de la suscripción MQL; en
  # producción el admin la añade (el formulario avisa si falta).
  def render_general_opt_in_in_template!(workspace, template_key: "contacto")
    path = LeadFormTemplate.form_page_path_for(template_key)
    import_lead_form_templates!(workspace) unless workspace.lead_form_templates.exists?(path: path)
    partial = workspace.lead_form_templates.find_by!(path: "#{LeadFormTemplate::PARTIALS_PREFIX}consent_fields")
    partial.update!(body: %({% subscription_opt_in slug: "general" %}\n#{partial.body}))
    workspace.lead_form_templates.find_by!(path: path).refresh_submission_schema!
  end

  def create_lead_form!(workspace, user:, pipeline: nil, **attrs)
    template_key = (attrs[:template_key] || attrs["template_key"] || "contacto").to_s
    path = LeadFormTemplate.form_page_path_for(template_key)
    import_lead_form_templates!(workspace) unless workspace.lead_form_templates.exists?(path: path)

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

  def demo_lead_params(overrides = {})
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

  def reserva_lead_params(overrides = {})
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

  def valid_lead_form_timestamp
    LeadForm.signed_timestamp(at: 10.seconds.ago)
  end

  def privacy_policy_hash_for(lead_form)
    get public_lead_form_path(lead_form.slug)
    match = response.body.match(/name="lead\[privacy_policy_hash\]"[^>]*value="([^"]+)"/)
    match&.captures&.first
  end

  def submission_key_for(lead_form)
    get public_lead_form_path(lead_form.slug)
    match = response.body.match(/name="lead\[_submission_key\]"[^>]*value="([^"]+)"/)
    match&.captures&.first
  end

  def contacto_lead_params_with_privacy(lead_form, overrides = {})
    contacto_lead_params(overrides).merge("privacy_policy_hash" => privacy_policy_hash_for(lead_form))
  end
end

RSpec.configure { |config| config.include LeadFormHelper }
