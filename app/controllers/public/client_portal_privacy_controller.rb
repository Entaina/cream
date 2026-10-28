module Public
  class ClientPortalPrivacyController < ApplicationController
    include ClientPortalSecurity
    include WorkspaceTemplateCsp

    layout "public_client_portal"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    rate_limit to: 60, within: 1.minute, name: "client_portal_privacy"

    def show
      @workspace = Workspace.find_by(slug: params[:workspace_slug])
      @policy_html = ClientPortal::PrivacyPolicy.html(@workspace) if @workspace
      head :not_found if @policy_html.blank?
    end
  end
end
