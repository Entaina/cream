module Public
  class OfferSharesController < ApplicationController
    include ClientPortalSecurity
    include ClientPortalConsent
    include OfferVersionPreview

    layout "public_client_portal"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :set_share_link

    rate_limit to: 10, within: 3.minutes, only: :create, name: "offer_share_access_request",
      with: -> { redirect_after_access_request }
    rate_limit to: 30, within: 1.minute, only: %i[show confirm access], name: "offer_share_show"

    def show
    end

    def create
      email = OfferAccessGrant.normalize_email(params[:email])
      if email.match?(URI::MailTo::EMAIL_REGEXP) &&
          !OfferAccessGrant.blocked?(offer: @share_link.offer, email: email) &&
          !OfferAccessGrant.limit_reached?(share_link: @share_link, email: email)
        grant, raw_token = OfferAccessGrant.issue!(share_link: @share_link, email: email)
        ClientPortalMailer.offer_access_link(grant: grant, raw_token: raw_token).deliver_later
      end

      redirect_after_access_request
    end

    # Confirmation page: mail scanners prefetch links with GET, so the token is only spent on POST.
    def confirm
      grant = OfferAccessGrant.find_pending(share_link: @share_link, raw_token: params[:grant_token])
      return render_access_expired unless grant

      load_consent_types(@share_link.workspace, grant.email)
    end

    def access
      pending = OfferAccessGrant.find_pending(share_link: @share_link, raw_token: params[:grant_token])
      if pending
        load_consent_types(@share_link.workspace, pending.email)
        return render_required_consent_missing(:confirm) if required_consent_missing?
      end

      grant = OfferAccessGrant.consume!(share_link: @share_link, raw_token: params[:grant_token])
      return render_access_expired unless grant

      offer = @share_link.offer
      version = offer.client_version
      person = ClientPortal::SharedAccess.ensure_contact!(
        deal: offer.deal,
        email: grant.email,
        source: "offer_share",
        offer_share_link: @share_link
      )
      ClientPortal::ConsentOffer.record!(workspace: @share_link.workspace, person: person, type_ids: params[:consent_type_ids],
        request: request, context: "offer_share")

      ClientPortal::OfferViewRecorder.record!(offer: offer, person: person, version: version, share_link: @share_link)
      render_offer_version(version)
    end

    private

    def set_share_link
      @share_link = OfferShareLink.active.includes(:person, offer: :deal).find_by(token: params[:token])
      head :not_found unless @share_link && share_link_usable?
    end

    # The link dies with the sharer's place on the deal, and with an offer that has nothing to show.
    def share_link_usable?
      offer = @share_link.offer
      offer.client_version.present? &&
        offer.deal.deal_contacts.exists?(person_id: @share_link.person_id)
    end

    def render_access_expired
      @share_url = public_offer_share_url(token: @share_link.token)
      render :access_expired, status: :gone
    end

    def redirect_after_access_request
      redirect_to public_offer_share_path(token: @share_link.token), notice: t("client_portal.offer_shares.link_sent")
    end
  end
end
