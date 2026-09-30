module PublicLayoutTemplates
  class Renderer
    CONTENT_INJECT_MARKER = "CREAM_PUBLIC_LAYOUT_CONTENT"

    def self.render(template:, content_html:, workspace:, view_context:)
      new(template:, content_html:, workspace:, view_context:).render
    end

    def initialize(template:, content_html:, workspace:, view_context:)
      @template = template
      @content_html = content_html.to_s
      @workspace = workspace
      @view_context = view_context
    end

    def render
      body = @template.body.gsub(LeadFormTemplate::CONTENT_PLACEHOLDER, CONTENT_INJECT_MARKER)
      lead_form = stub_lead_form
      source = LeadFormTemplates::OverridingSource.new(
        workspace: @workspace,
        overrides: {@template.path => body}
      )
      html = LeadFormTemplates::Renderer.new(
        workspace: @workspace,
        lead_form: lead_form,
        view_context: @view_context,
        params: {},
        source: source
      ).render(@template.path)
      html.gsub(CONTENT_INJECT_MARKER, @content_html).html_safe
    end

    private

    def stub_lead_form
      LeadForm.new(
        workspace: @workspace,
        slug: LeadFormTemplates::PagePreview::PREVIEW_SLUG,
        name: @workspace.name,
        template_key: "contacto",
        collects_company: false,
        hidden_field_keys: [],
        pipeline_routes: {}
      )
    end
  end
end
