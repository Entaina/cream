# Offers (named containers of PDF/HTML versions) attached to a deal. Access
# follows the deal: anyone who can view it can preview its offers, anyone who
# can edit it can add or remove them. Authorization happens against the parent
# deal in #set_deal, so the offer-scoped Pundit verifiers don't apply here.
class OffersController < ApplicationController
  include OfferVersionPreview

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_deal
  before_action :authorize_view, only: :show
  before_action :authorize_edit, only: %i[new create]
  before_action :authorize_destroy, only: :destroy

  def new
    @offer = @deal.offers.new
    @version = @offer.versions.new
  end

  # Creates the offer together with its first version.
  def create
    @offer = @deal.offers.new(name: offer_params[:name], workspace: current_workspace, user: current_user)
    @version = @offer.versions.new(version_params.merge(user: current_user))
    @offer.name = @version.file.filename.base if @offer.name.blank? && @version.file.attached?

    if [@offer.valid?, @version.valid?].all? && @offer.save
      redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Preview of the current (latest) version, meant to be opened in its own browser tab.
  def show
    render_offer_version(@deal.offers.find(params[:id]).current_version)
  end

  def destroy
    @deal.offers.find(params[:id]).destroy
    redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offers.removed"), status: :see_other
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
  end

  def authorize_view = authorize(@deal, :show?)

  def authorize_edit = authorize(@deal, :update?)

  def authorize_destroy = authorize(@deal, :destroy?)

  def offer_params
    params.fetch(:offer, {}).permit(:name)
  end

  def version_params
    params.fetch(:offer_version, {}).permit(:html_body, :comment, :file)
  end
end
