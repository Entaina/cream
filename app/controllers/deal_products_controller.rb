# Product lines on a deal. Unit price defaults from the catalogue on create
# and can be overridden afterwards; the deal value is recomputed automatically.
class DealProductsController < ApplicationController
  # Authorization happens against the parent deal in #set_deal; this controller
  # never lists records, so the index-scoped Pundit verifiers don't apply.
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_deal

  def create
    @line_item = @deal.deal_products.new(line_item_params)
    if @line_item.save
      redirect_to @deal, notice: t("flashes.deal_products.added")
    else
      redirect_to @deal, alert: @line_item.errors.full_messages.to_sentence
    end
  end

  def update
    @line_item = @deal.deal_products.find(params[:id])
    if @line_item.update(line_item_params)
      redirect_to @deal, notice: t("flashes.deal_products.line_updated")
    else
      redirect_to @deal, alert: @line_item.errors.full_messages.to_sentence
    end
  end

  def destroy
    @deal.deal_products.find(params[:id]).destroy
    redirect_to @deal, notice: t("flashes.deal_products.removed"), status: :see_other
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
    authorize @deal, :update?
  end

  def line_item_params
    params.require(:deal_product).permit(:product_id, :quantity, :unit_price, :edition_id, :edition_name)
  end
end
