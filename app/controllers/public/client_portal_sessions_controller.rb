module Public
  class ClientPortalSessionsController < ApplicationController
    include ClientPortalSecurity
    include ClientPortalAuthentication
    include ClientPortalConsent
    include WorkspaceTemplateCsp

    layout "public_client_portal"

    allow_unauthenticated_access only: %i[new create show consume destroy]
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_workspace_from_slug

    rate_limit to: 10, within: 3.minutes, only: :create, name: "client_portal_login",
      with: -> { redirect_after_login_request }
    rate_limit to: 30, within: 1.minute, only: %i[new show consume], name: "client_portal_session_show"

    def new
    end

    def create
      email = OfferAccessGrant.normalize_email(params[:email])
      if email.match?(URI::MailTo::EMAIL_REGEXP) &&
          ClientPortal::Access.allowed?(workspace: @workspace, email: email) &&
          !ClientPortalLoginGrant.limit_reached?(workspace: @workspace, email: email)
        _grant, raw_token = ClientPortalLoginGrant.issue!(workspace: @workspace, email: email)
        ClientPortalMailer.login_link(workspace: @workspace, email: email, token: raw_token).deliver_later
      end

      redirect_after_login_request
    end

    # Confirmation page: mail scanners prefetch links with GET, so the token is only spent on POST.
    def show
      grant = ClientPortalLoginGrant.where(workspace_id: @workspace.id).pending_for(params[:token]).first
      unless grant
        return redirect_to client_portal_root_path(workspace_slug: @workspace.slug), alert: t("client_portal.sessions.invalid_link")
      end

      load_consent_types(@workspace, grant.email)
    end

    def consume
      pending = ClientPortalLoginGrant.where(workspace_id: @workspace.id).pending_for(params[:token]).first
      if pending
        load_consent_types(@workspace, pending.email)
        return render_required_consent_missing(:show) if required_consent_missing?
      end

      grant = ClientPortalLoginGrant.consume!(workspace: @workspace, raw_token: params[:token])
      unless grant
        return redirect_to client_portal_root_path(workspace_slug: @workspace.slug), alert: t("client_portal.sessions.invalid_link")
      end
      unless ClientPortal::Access.allowed?(workspace: @workspace, email: grant.email)
        return redirect_to client_portal_root_path(workspace_slug: @workspace.slug), alert: t("client_portal.sessions.no_access")
      end

      if (person = Person.find_by_email(@workspace, grant.email))
        ClientPortal::ConsentOffer.record!(workspace: @workspace, person: person, type_ids: params[:consent_type_ids],
          request: request, context: "login")
      end
      ClientPortal::SessionCookie.write(cookies, workspace_id: @workspace.id, email: grant.email)
      redirect_to client_portal_offers_path(workspace_slug: @workspace.slug), notice: t("client_portal.sessions.signed_in")
    end

    def destroy
      ClientPortal::SessionCookie.clear(cookies)
      redirect_to client_portal_root_path(workspace_slug: @workspace.slug), notice: t("client_portal.sessions.signed_out")
    end

    private

    def set_workspace_from_slug
      @workspace = Workspace.find_by(slug: params[:workspace_slug])
      head :not_found unless @workspace
    end

    def redirect_after_login_request
      redirect_to client_portal_root_path(workspace_slug: @workspace.slug), notice: t("client_portal.sessions.link_sent")
    end
  end
end
