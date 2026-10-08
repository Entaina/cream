class DealPortalInviteLinksController < ApplicationController
  before_action :set_deal

  def create
    authorize @deal, :update?
    link = DealPortalInviteLink.find_or_initialize_by(deal: @deal, workspace: current_workspace)
    link.revoked_at = nil
    link.save!
    redirect_to deal_path(@deal, tab: "information"), notice: t("flashes.deal_portal_invite_links.ready")
  end

  def destroy
    authorize @deal, :update?
    @deal.portal_invite_link&.revoke!
    redirect_to deal_path(@deal, tab: "information"), notice: t("flashes.deal_portal_invite_links.revoked"), status: :see_other
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
  end
end
