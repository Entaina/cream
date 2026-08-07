module LeadFormTemplates
  class PreviewViewContext
    def initialize(view_context)
      @view_context = view_context
    end

    def public_lead_form_path(_slug)
      "#"
    end

    def form_authenticity_token
      @view_context.form_authenticity_token
    end

    def privacy_path
      @view_context.privacy_path
    end

    def method_missing(name, ...)
      @view_context.public_send(name, ...)
    end

    def respond_to_missing?(name, include_private = false)
      @view_context.respond_to?(name, include_private) || super
    end
  end
end
