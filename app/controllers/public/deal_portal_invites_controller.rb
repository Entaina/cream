module Public
  class DealPortalInvitesController < ApplicationController
    include ClientPortalSecurity
    include ClientPortalConsent
    include WorkspaceTemplateCsp

    layout "public_client_portal"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_workspace_from_slug
    before_action :set_invite_link

    rate_limit to: 10, within: 3.minutes, only: :create, name: "deal_portal_invite_request",
      with: -> { redirect_after_access_request }
    rate_limit to: 30, within: 1.minute, only: %i[show confirm access], name: "deal_portal_invite_show"

    def show
      @deal = @invite_link.deal
    end

    def create
      email = OfferAccessGrant.normalize_email(params[:email])
      if email.match?(URI::MailTo::EMAIL_REGEXP) && !DealPortalAccessGrant.limit_reached?(invite_link: @invite_link)
        grant, raw_token = DealPortalAccessGrant.issue!(invite_link: @invite_link, email: email)
        ClientPortalMailer.deal_portal_invite_link(grant: grant, raw_token: raw_token).deliver_later
      end

      redirect_after_access_request
    end

    # Confirmation page: mail scanners prefetch links with GET, so the token is only spent on POST.
    def confirm
      @deal = @invite_link.deal
      grant = DealPortalAccessGrant.find_pending(invite_link: @invite_link, raw_token: params[:grant_token])
      return render_access_expired unless grant

      load_consent_types(@workspace, grant.email)
    end

    def access
      pending = DealPortalAccessGrant.find_pending(invite_link: @invite_link, raw_token: params[:grant_token])
      if pending
        @deal = @invite_link.deal
        load_consent_types(@workspace, pending.email)
        return render_required_consent_missing(:confirm) if required_consent_missing?
      end

      grant = DealPortalAccessGrant.consume!(invite_link: @invite_link, raw_token: params[:grant_token])
      return render_access_expired unless grant

      person = ClientPortal::SharedAccess.ensure_contact!(deal: @invite_link.deal, email: grant.email, source: "portal_invite")
      ClientPortal::ConsentOffer.record!(workspace: @workspace, person: person, type_ids: params[:consent_type_ids],
        request: request, context: "portal_invite")
      ClientPortal::SessionCookie.write(cookies, workspace_id: @workspace.id, email: grant.email)
      redirect_to client_portal_offers_path(workspace_slug: @workspace.slug), notice: t("client_portal.deal_invites.signed_in")
    end

    private

    def set_workspace_from_slug
      @workspace = Workspace.find_by(slug: params[:workspace_slug])
      head :not_found unless @workspace
    end

    def set_invite_link
      @invite_link = DealPortalInviteLink.active.includes(:deal).find_by(token: params[:token], workspace_id: @workspace.id)
      head :not_found unless @invite_link
    end

    def render_access_expired
      @invite_url = client_portal_deal_portal_invite_url(workspace_slug: @workspace.slug, token: @invite_link.token)
      render :access_expired, status: :gone
    end

    def redirect_after_access_request
      redirect_to client_portal_deal_portal_invite_path(workspace_slug: @workspace.slug, token: @invite_link.token),
        notice: t("client_portal.deal_invites.link_sent")
    end
  end
end
