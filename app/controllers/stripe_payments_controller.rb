class StripePaymentsController < ApplicationController
  include RequiresFeature

  requires_feature :stripe_payments

  helper_method :index_query_params

  def index
    @connection = current_workspace.stripe_connections.first
    @status = StripePayment::STATUSES.include?(params[:status]) ? params[:status] : "pending_review"
    @counts = policy_scope(current_workspace.stripe_payments).group(:status).count

    payments = policy_scope(current_workspace.stripe_payments)
      .where(status: @status)
      .search(params[:q])
      .includes(:deal, :suggested_deal, :suggested_person)
      .recent_first
    @pagy, @payments = pagy(:offset, payments)
  end

  def show
    @payment = current_workspace.stripe_payments
      .includes(:deal, :suggested_deal, :suggested_person, :matched_by)
      .find(params[:id])
    authorize @payment
  end

  def match
    payment = current_workspace.stripe_payments.find(params[:id])
    authorize payment

    deal_id = params[:deal_id].presence || payment.suggested_deal_id
    deal = current_workspace.deals.find_by(id: deal_id)
    if deal.nil?
      redirect_back_to_inbox(alert: t("flashes.stripe.pick_deal")) and return
    end

    payment.match!(deal, user: current_user)
    redirect_back_to_inbox(notice: t("flashes.stripe.linked", deal: deal.name))
  end

  def ignore
    payment = current_workspace.stripe_payments.find(params[:id])
    authorize payment
    payment.ignore!(user: current_user)
    redirect_back_to_inbox(notice: t("flashes.stripe.ignored"))
  end

  def unignore
    payment = current_workspace.stripe_payments.find(params[:id])
    authorize payment
    payment.unignore!
    redirect_back_to_inbox(status: "pending_review", notice: t("flashes.stripe.review"))
  end

  private

  # Actions can be triggered from the inbox or from a payment's detail page.
  def redirect_back_to_inbox(status: params[:status], notice: nil, alert: nil)
    redirect_back fallback_location: stripe_payments_path(index_query_params(status: status)),
      notice: notice, alert: alert
  end

  # Minimal counterpart of ViewScoped#index_query_params so shared/_pagination works.
  def index_query_params(overrides = {})
    {status: params[:status], q: params[:q]}.merge(overrides).compact_blank
  end
end
