require "rails_helper"

RSpec.describe PublicLayoutTemplates::Renderer do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "injects booking widget html at the content placeholder" do
    template = workspace.lead_form_templates.create!(
      kind: "layout",
      path: "public/layouts/test_wrap",
      partial: false,
      body: "<header data-test=\"site-header\">Site</header>{{ content }}<footer>End</footer>"
    )
    workspace.update!(public_layout_template: template)

    html = described_class.render(
      template: template,
      content_html: "<main data-test=\"booking-widget\">Widget</main>",
      workspace: workspace,
      view_context: LeadFormTemplates::NullViewContext.new
    )

    expect(html).to include('data-test="site-header"')
    expect(html).to include('data-test="booking-widget"')
    expect(html).to include("<footer>End</footer>")
    expect(html).not_to include("{{ content }}")
  end
end
