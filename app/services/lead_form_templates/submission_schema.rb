module LeadFormTemplates
  class SubmissionSchema
    def self.build(lead_form:, product: nil, open_editions: nil, params: {})
      template = lead_form.workspace.lead_form_templates.find_by(
        path: LeadFormTemplate.form_page_path_for(lead_form.template_key)
      )
      product ||= lead_form.resolved_product(product_id_param: params["product_id"])
      open_editions = lead_form.open_editions_for(product) if open_editions.nil?
      open_editions ||= []

      schema = if template&.submission_schema.present?
        HtmlSchema.from_stored(template.submission_schema)
      else
        html = FormHtmlRenderer.render(
          lead_form: lead_form,
          product: product,
          open_editions: open_editions,
          params: {lead: params}
        )
        HtmlSchema.parse(html)
      end

      schema.apply_context(lead_form: lead_form, product: product, open_editions: open_editions)
    end
  end
end
