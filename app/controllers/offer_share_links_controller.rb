class OfferShareLinksController < ApplicationController
  before_action :set_deal
  before_action :set_offer
  before_action :set_share_link

  def destroy
    authorize @deal, :update?
    @share_link.revoke!
    redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offer_share_links.revoked"), status: :see_other
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
  end

  def set_offer
    @offer = @deal.offers.find(params[:offer_id])
  end

  def set_share_link
    @share_link = @offer.share_links.find(params[:id])
  end
end
