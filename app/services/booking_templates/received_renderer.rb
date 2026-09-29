module BookingTemplates
  class ReceivedRenderer
    def self.render(workspace:, template:, view_context:, event_slug:, booking_page:)
      new(
        workspace: workspace,
        template: template,
        view_context: view_context,
        event_slug: event_slug,
        booking_page: booking_page
      ).render
    end

    def initialize(workspace:, template:, view_context:, event_slug:, booking_page:)
      @workspace = workspace
      @template = template
      @view_context = view_context
      @event_slug = event_slug
      @booking_page = booking_page
    end

    def render
      LeadFormTemplates::Renderer.new(
        workspace: @workspace,
        lead_form: stub_lead_form,
        view_context: @view_context,
        params: {},
        extra_assigns: {"evento" => @event_slug},
        source: LeadFormTemplates::Source.new(workspace: @workspace)
      ).render(@template.path)
    end

    private

    def stub_lead_form
      LeadForm.new(
        workspace: @workspace,
        slug: LeadFormTemplates::PagePreview::PREVIEW_SLUG,
        name: @booking_page.name,
        template_key: "contacto",
        collects_company: false,
        hidden_field_keys: [],
        pipeline_routes: {}
      )
    end
  end
end
