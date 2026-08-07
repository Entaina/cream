module LeadFormTemplates
  class PagePreview
    PREVIEW_SLUG = "template-preview"

    def self.render(template:, view_context:, body: nil, product_id: nil)
      new(template: template, view_context: view_context, body: body, product_id: product_id).render
    end

    def initialize(template:, view_context:, body: nil, product_id: nil)
      @template = template
      @workspace = template.workspace
      @view_context = view_context
      @body_override = body
      @product_id = product_id
    end

    def render
      lead_form = sample_lead_form
      product, open_editions = resolve_product(lead_form)

      Renderer.new(
        workspace: @workspace,
        lead_form: lead_form,
        view_context: @view_context,
        params: {},
        product: product,
        open_editions: open_editions,
        source: preview_source
      ).render(@template.path)
    end

    private

    def preview_source
      return Source.new(workspace: @workspace) if @body_override.blank?

      OverridingSource.new(
        workspace: @workspace,
        overrides: { @template.path => @body_override }
      )
    end

    def sample_lead_form
      find_sample_lead_form || stub_lead_form
    end

    def find_sample_lead_form
      key = @template.template_key
      return if key.blank?

      @workspace.lead_forms.find_by(template_key: key)
    end

    def stub_lead_form
      LeadForm.new(
        workspace: @workspace,
        slug: PREVIEW_SLUG,
        name: "Vista previa: #{@template.display_name}",
        template_key: @template.template_key || "contacto",
        collects_company: true,
        hidden_field_keys: [],
        pipeline_routes: {}
      )
    end

    def resolve_product(lead_form)
      product = @workspace.products.find_by(id: @product_id) if @product_id.present?
      product ||= @workspace.products.find_by(id: lead_form.product_id) if lead_form.product_id.present?
      product ||= sample_product
      open_editions = product ? lead_form.open_editions_for(product).to_a : []
      [ product, open_editions ]
    end

    def sample_product
      @workspace.products
        .joins(:editions)
        .merge(Edition.not_started)
        .distinct
        .first || @workspace.products.first
    end
  end
end
