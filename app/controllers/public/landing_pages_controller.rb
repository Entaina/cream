module Public
  class LandingPagesController < ApplicationController
    include WorkspaceTemplateCsp

    layout "public_lead_form"

    allow_unauthenticated_access only: :show
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def show
      return head :not_found unless CreamFeatures.enabled?(:web_tracking)

      workspace = Workspace.find_by!(slug: params[:workspace_slug])
      @template = workspace.lead_form_templates.landing_pages.find_by!(page_slug: params[:slug])
      @page_html = LeadFormTemplates::PagePreview.render(
        template: @template,
        view_context: view_context
      )
    rescue ActiveRecord::RecordNotFound, Liquid::Error
      head :not_found
    end
  end
end
