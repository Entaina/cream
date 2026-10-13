require "rails_helper"

RSpec.describe "field Liquid tag" do
  def render_markup(markup)
    environment = LeadFormTemplates::Renderer.build_environment
    template = Liquid::Template.parse(markup, environment: environment)
    renderer = LeadFormTemplates::FieldRenderer.new(view_context: nil, params: {})
    template.render!({}, registers: {field_renderer: renderer})
  end

  it "renders a checkbox with default checked and unchecked values" do
    html = render_markup('{% field type: "checkbox", name: "newsletter_opt_in", label: "Quiero la newsletter" %}')

    expect(html).to include('type="checkbox"')
    expect(html).to include('value="1"')
    expect(html).to include('type="hidden" name="lead[newsletter_opt_in]" value="0"')
  end

  it "renders a textarea with the default row count" do
    html = render_markup('{% field type: "textarea", name: "message", label: "Mensaje" %}')

    expect(html).to include('rows="4"')
  end

  it "allows overriding the textarea row count" do
    html = render_markup('{% field type: "textarea", name: "message", label: "Mensaje", rows: "8" %}')

    expect(html).to include('rows="8"')
  end

  it "allows overriding the checkbox values" do
    html = render_markup('{% field type: "checkbox", name: "terms", label: "Acepto", value: "yes", unchecked_value: "no" %}')

    expect(html).to include('value="yes"')
    expect(html).to include('type="hidden" name="lead[terms]" value="no"')
  end
end
