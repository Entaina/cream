# Offers (PDF or HTML documents) attached to a deal. Access follows the deal:
# anyone who can view it can preview its offers, anyone who can edit it can
# add or remove them. Authorization happens against the parent deal in
# #set_deal, so the offer-scoped Pundit verifiers don't apply here.
class OffersController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_deal
  before_action :authorize_view, only: :show
  before_action :authorize_edit, only: %i[new create destroy]

  # Sandbox: the offer is arbitrary user-supplied HTML served from the app's
  # origin, so it must never run scripts or reach the user's session.
  PREVIEW_CSP = "sandbox; default-src 'none'; img-src * data:; style-src * 'unsafe-inline'; font-src * data:"

  def new
    @offer = @deal.offers.new
  end

  def create
    @offer = @deal.offers.new(offer_params.merge(workspace: current_workspace, user: current_user))
    if @offer.save
      redirect_to deal_path(@deal, tab: "offers"), notice: t("flashes.offers.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Preview, meant to be opened in its own browser tab.
  def show
    offer = @deal.offers.find(params[:id])
    if offer.pdf?
      send_data offer.file.download, type: "application/pdf", disposition: "inline", filename: offer.file.filename.to_s
    else
      response.headers["Content-Security-Policy"] = PREVIEW_CSP
      render body: offer.html_content, content_type: "text/html"
    end
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

  def offer_params
    params.require(:offer).permit(:name, :html_body, :file)
  end
end
