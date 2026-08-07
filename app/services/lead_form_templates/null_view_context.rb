module LeadFormTemplates
  # Minimal view context for rendering lead form HTML outside a request cycle.
  class NullViewContext
    def public_lead_form_path(slug)
      "/f/#{slug}"
    end

    def form_authenticity_token
      "schema-render-token"
    end

    def privacy_path
      "/privacy"
    end
  end
end
