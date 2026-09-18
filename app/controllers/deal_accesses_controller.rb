class DealAccessesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  before_action :set_deal

  def create
    authorize @deal, :manage_collaborators?

    user = current_workspace.users.find(params.require(:user_id))
    if user.id == @deal.owner_id
      redirect_to @deal, alert: t("flashes.deal_accesses.owner_has_access")
      return
    end

    access = @deal.deal_accesses.find_or_create_by!(user: user)
    if access.previously_new_record?
      redirect_to @deal, notice: t("flashes.deal_accesses.collaborator_added", name: user.name)
    else
      redirect_to @deal, alert: t("flashes.deal_accesses.already_has_access", name: user.name)
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @deal, alert: e.record.errors.full_messages.to_sentence
  end

  def destroy
    authorize @deal, :manage_collaborators?

    access = @deal.deal_accesses.find(params[:id])
    access.destroy!
    redirect_to @deal, notice: t("flashes.deal_accesses.collaborator_removed"), status: :see_other
  end

  private

  def set_deal
    @deal = policy_scope(current_workspace.deals).find(params[:deal_id])
  end
end
