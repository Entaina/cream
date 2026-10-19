# Versions of an offer. Access follows the parent deal (see OffersController).
class OfferVersionsController < ApplicationController
  include OfferVersionPreview

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_offer
  before_action :authorize_view, only: :show
  before_action :authorize_edit, only: %i[new create publish]
  before_action :authorize_destroy, only: :destroy

  def new
    @version = @offer.versions.new
  end

  def create
    @version = @offer.versions.new(version_params.merge(user: current_user))
    if @version.save
      redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offer_versions.created", number: @version.number)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Preview of one specific version, meant to be opened in its own browser tab.
  def show
    render_offer_version(@offer.versions.find(params[:id]))
  end

  # Makes a draft version visible to clients. Newer drafts stay drafts.
  def publish
    version = @offer.versions.find(params[:id])
    version.publish!
    redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offer_versions.published", number: version.number), status: :see_other
  end

  # The last remaining version can't be removed: delete the offer instead.
  def destroy
    version = @offer.versions.find(params[:id])
    if @offer.versions.count > 1
      version.destroy
      redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offer_versions.removed", number: version.number), status: :see_other
    else
      redirect_to deal_path(@deal, tab: "offers"), alert: t("flashes.offer_versions.last_version"), status: :see_other
    end
  end

  private

  def set_offer
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
    @offer = @deal.offers.find(params[:offer_id])
  end

  def authorize_view = authorize(@deal, :show?)

  def authorize_edit = authorize(@deal, :update?)

  def authorize_destroy = authorize(@deal, :destroy?)

  def version_params
    params.fetch(:offer_version, {}).permit(:html_body, :comment, :file)
  end
end
