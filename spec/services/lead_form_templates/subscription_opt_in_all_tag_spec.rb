require "rails_helper"

RSpec.describe "subscription_opt_in_all Liquid tag" do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let(:lead_form) { create_lead_form!(workspace, user: member, template_key: "newsletter") }

  before do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
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

  it "renders a subscribe_all checkbox with active type names in the default label" do
    html = render_markup("{% subscription_opt_in_all %}")

    expect(html).to include('name="lead[subscribe_all]"')
    expect(html).to include('name="lead[subscribe_all_label]"')
    expect(html).to include("General")
    expect(html).to include("Newsletter")
  end

  it "allows overriding the label in the tag" do
    html = render_markup('{% subscription_opt_in_all label: "Etiqueta custom" %}')

    expect(html).to include("Etiqueta custom")
    expect(html).to include('value="Etiqueta custom"')
  end

  it "returns empty output when marketing consent feature is disabled" do
    allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(false)

    expect(render_markup("{% subscription_opt_in_all %}")).to eq("")
  end

  it "returns empty output when there are no active subscription types" do
    workspace.subscription_types.update_all(active: false)

    expect(render_markup("{% subscription_opt_in_all %}")).to eq("")
  end

  it "omits excluded types from the label and hidden exclude field" do
    workspace.subscription_types.find_by!(slug: "events").update!(excluded_from_subscribe_all: true)

    html = render_markup("{% subscription_opt_in_all %}")

    expect(html).to include("General")
    expect(html).to include("Newsletter")
    expect(html).not_to include("Eventos")
  end

  it "supports exclude slugs in the tag for this form only" do
    html = render_markup('{% subscription_opt_in_all exclude: "newsletter, events" %}')

    expect(html).to include('name="lead[subscribe_all_exclude_slugs]"')
    expect(html).to include('value="newsletter,events"')
    expect(html).not_to include("Newsletter")
    expect(html).to include("General")
  end
end
