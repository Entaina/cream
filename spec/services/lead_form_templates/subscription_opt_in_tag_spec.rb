require "rails_helper"

RSpec.describe "subscription_opt_in Liquid tag" do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:lead_form) { create_lead_form!(workspace, user: member, template_key: "entrenadores") }

  before do
    SubscriptionType.ensure_defaults!(workspace)
  end

  def render_markup(markup, lead_form_override: lead_form)
    environment = LeadFormTemplates::Renderer.build_environment
    template = Liquid::Template.parse(markup, environment: environment)
    renderer = LeadFormTemplates::FieldRenderer.new(view_context: nil, params: {})
    template.render!(
      {},
      registers: {
        lead_form: lead_form_override,
        field_renderer: renderer
      }
    )
  end

  it "renders a checkbox using the subscription type consent field key" do
    html = render_markup('{% subscription_opt_in slug: "newsletter" %}')

    expect(html).to include('name="lead[newsletter_opt_in]"')
    expect(html).to include("Quiero recibir la newsletter de Entaina")
  end

  it "uses marketing consent text for the primary MQL subscription type" do
    mql_form = create_lead_form!(
      workspace,
      user: member,
      destination: "mql",
      marketing_consent_text: "Texto personalizado MQL"
    )
    html = render_markup('{% subscription_opt_in slug: "general" %}', lead_form_override: mql_form)

    expect(html).to include('name="lead[marketing_consent]"')
    expect(html).to include("Texto personalizado MQL")
  end

  it "allows overriding the label in the tag" do
    html = render_markup('{% subscription_opt_in slug: "newsletter", label: "Etiqueta custom" %}')

    expect(html).to include("Etiqueta custom")
  end

  it "returns empty output when the subscription type has no consent field" do
    events = workspace.subscription_types.find_by!(slug: "events")
    expect(events.consent_field_key).to be_nil

    expect(render_markup('{% subscription_opt_in slug: "events" %}')).to eq("")
  end
end
