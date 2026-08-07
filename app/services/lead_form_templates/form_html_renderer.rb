module LeadFormTemplates
  class FormHtmlRenderer
    def self.render(lead_form:, product: nil, open_editions: [], params: {}, view_context: NullViewContext.new)
      template = lead_form.workspace.lead_form_templates.find_by(
        path: LeadFormTemplate.form_page_path_for(lead_form.template_key)
      )
      raise Liquid::FileSystemError, "Template not found" if template.nil?

      render_template(
        template: template,
        lead_form: lead_form,
        product: product,
        open_editions: open_editions,
        params: params,
        view_context: view_context
      )
    end

    def self.render_template(template:, lead_form:, product: nil, open_editions: [], params: {}, view_context: NullViewContext.new)
      Renderer.new(
        workspace: template.workspace,
        lead_form: lead_form,
        view_context: view_context,
        params: params,
        product: product,
        open_editions: open_editions
      ).render(template.path)
    end
  end
end
