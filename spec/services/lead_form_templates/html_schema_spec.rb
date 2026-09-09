require "rails_helper"

RSpec.describe LeadFormTemplates::HtmlSchema do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }

  before do
    import_lead_form_templates!(workspace)
    SubscriptionType.ensure_defaults!(workspace)
  end

  def schema_for(template_key:, **lead_form_attrs)
    lead_form = create_lead_form!(workspace, user: member, template_key: template_key, **lead_form_attrs)
    html = LeadFormTemplates::FormHtmlRenderer.render(lead_form: lead_form)
    described_class.parse(html)
  end

  it "extracts required fields and select options from rendered HTML" do
    schema = schema_for(template_key: "contacto")

    email = schema.fields.find { |field| field.name == "email" }
    help_type = schema.fields.find { |field| field.name == "help_type" }

    expect(email).to have_attributes(input_type: "email", required: true)
    expect(help_type).to have_attributes(
      input_type: "select",
      required: true,
      allowed_values: %w[curso entrenamiento proyecto_consultoria otro]
    )
    expect(schema.allowed_param_keys).to include("gdpr_consent", LeadForm::HONEYPOT_FIELD, "utm_source")
  end

  it "includes gdpr consent from raw HTML partials" do
    schema = schema_for(template_key: "contacto")
    consent = schema.fields.find { |field| field.name == "gdpr_consent" }

    expect(consent).to have_attributes(input_type: "checkbox", required: true, checkbox_value: "1")
  end

  it "respects conditional fields from Liquid" do
    schema_with_company = schema_for(template_key: "demo", collects_company: true)
    schema_without_company = schema_for(template_key: "demo", collects_company: false)

    expect(schema_with_company.fields.map(&:name)).to include("company_name")
    expect(schema_without_company.fields.map(&:name)).not_to include("company_name")
  end

  it "validates required fields and allowed values" do
    schema = schema_for(template_key: "contacto")

    expect {
      schema.validate!(
        "email" => "not-an-email",
        "first_name" => "Ana",
        "last_name" => "García",
        "phone" => "600111222",
        "help_type" => "invalid",
        "how_heard" => "evento",
        "gdpr_consent" => "1"
      )
    }.to raise_error(ActiveRecord::RecordInvalid) { |error|
      expect(error.record.errors.full_messages).to include("Email is invalid", "help type is invalid")
    }
  end

  it "rejects unknown submitted fields" do
    schema = schema_for(template_key: "newsletter")

    expect {
      schema.validate!(
        "email" => "lead@example.com",
        "first_name" => "Ana",
        "last_name" => "García",
        "gdpr_consent" => "1",
        "injected_field" => "malicious"
      )
    }.to raise_error(ActiveRecord::RecordInvalid, /Unknown field injected_field/)
  end

  it "allows configured consent field keys from subscription types" do
    schema = schema_for(template_key: "newsletter").apply_context(
      lead_form: create_lead_form!(workspace, user: member, template_key: "newsletter"),
      product: nil,
      open_editions: []
    )

    expect(schema.allowed_param_keys).to include("newsletter_opt_in", "marketing_consent")
  end
end
