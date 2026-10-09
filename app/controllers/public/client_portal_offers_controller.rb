module Public
  class ClientPortalOffersController < ApplicationController
    include ClientPortalSecurity
    include ClientPortalAuthentication
    include OfferVersionPreview

    layout "public_client_portal"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_workspace_from_slug
    before_action :require_client_portal_session!
    before_action :set_offer, only: %i[show share create_share revoke_access]
    before_action :set_sharing_person, only: %i[share create_share revoke_access]

    def index
      @offers_by_deal = scoped_offers.joins(:deal)
        .includes(deal: :company, versions: { file_attachment: :blob })
        .order("deals.name ASC, offers.name ASC")
        .group_by(&:deal)
    end

    def show
      version = @offer.current_version
      return head :not_found unless version

      person = client_portal_person_for_deal(@offer.deal)
      return head :not_found unless person

      unless client_portal_preview?
        ClientPortal::OfferViewRecorder.record!(offer: @offer, person: person, version: version)
      end
      render_offer_version(version)
    end

    def share
      @share_link = OfferShareLink.active.find_by(offer: @offer, person: @sharing_person)
      @share_url = public_offer_share_url(token: @share_link.token) if @share_link
      @guest_accesses = guest_accesses
    end

    def create_share
      return redirect_client_portal_preview_read_only if client_portal_preview?

      link = OfferShareLink.find_or_initialize_by(offer: @offer, person: @sharing_person, workspace: @workspace)
      # A link the sales team revoked stays revoked; the contact can't silently re-enable it.
      link.save! if link.new_record?
      redirect_to share_client_portal_offer_path(workspace_slug: @workspace.slug, id: @offer.id), status: :see_other
    end

    def revoke_access
      return redirect_client_portal_preview_read_only if client_portal_preview?

      grant = OfferAccessGrant.for_offer(@offer).find_by(id: params[:grant_id])
      return head :not_found unless grant

      grant.revoke_for_offer!
      redirect_to share_client_portal_offer_path(workspace_slug: @workspace.slug, id: @offer.id),
        status: :see_other, notice: t("client_portal.offers.access_revoked", email: grant.email)
    end

    private

    # One row per email: the most recent link, flagged as revoked if any of that email's links were.
    def guest_accesses
      OfferAccessGrant.for_offer(@offer).includes(offer_share_link: :person).order(created_at: :desc)
        .group_by(&:email)
        .map { |_email, grants| { grant: grants.first, revoked: grants.any?(&:revoked?), opened_at: grants.filter_map(&:used_at).min } }
        .select { |access| access[:revoked] || access[:opened_at] || access[:grant].expires_at.future? }
    end

    def set_workspace_from_slug
      @workspace = Workspace.find_by(slug: params[:workspace_slug])
      head :not_found unless @workspace
    end

    def scoped_offers
      Offer.visible_to_contact(@workspace, client_portal_email)
    end

    def set_offer
      @offer = scoped_offers.find_by(id: params[:id])
      head :not_found unless @offer
    end

    def set_sharing_person
      @sharing_person = client_portal_person_for_deal(@offer.deal)
      head :not_found unless @sharing_person
    end

    def redirect_client_portal_preview_read_only
      redirect_to share_client_portal_offer_path(workspace_slug: @workspace.slug, id: @offer.id),
        status: :see_other, alert: t("client_portal.preview.read_only")
    end
  end
end
