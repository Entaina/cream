module LeadFormTemplates
  class Renderer
    def initialize(workspace:, lead_form:, view_context:, params:, product: nil, open_editions: [], source: nil, privacy_policy_hash: nil, submission_key: nil)
      @workspace = workspace
      @lead_form = lead_form
      @view_context = view_context
      @params = params
      @product = product
      @open_editions = open_editions
      @privacy_policy_hash = privacy_policy_hash
      @submission_key = submission_key
      @source = source || Source.new(workspace: workspace)
      @field_renderer = FieldRenderer.new(view_context: view_context, params: params, open_editions: open_editions)
      @environment = self.class.build_environment
    end

    def self.build_environment
      Liquid::Environment.build(tags: Liquid::Environment.default.tags.merge(Tags::REGISTRY))
    end

    def render(path)
      body = @source.find_body(path)
      raise Liquid::FileSystemError, "Template not found: #{path}" if body.blank?

      template = Liquid::Template.parse(body, environment: @environment)
      template.render!(build_assigns, registers: build_registers).html_safe
    end

    private

    def build_assigns
      {
        "lead_form" => Drops::LeadFormDrop.new(@lead_form),
        "product" => Drops::ProductDrop.new(@product),
        "open_editions" => @open_editions.map { |edition| Drops::EditionDrop.new(edition) }
      }
    end

    def build_registers
      {
        template_renderer: self,
        field_renderer: @field_renderer,
        lead_form: @lead_form,
        product: @product,
        open_editions: @open_editions,
        form_action: @view_context.public_lead_form_path(@lead_form.slug),
        csrf_token: @view_context.form_authenticity_token,
        privacy_url: @view_context.public_lead_form_privacy_path(@lead_form.slug),
        privacy_policy_hash: @privacy_policy_hash,
        submission_key: @submission_key,
        flash_alert: (@view_context.flash[:alert] if @view_context.respond_to?(:flash))
      }
    end
  end
end
