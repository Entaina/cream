class MembershipsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: %i[update destroy]

  def update
    membership = policy_scope(Membership).find(params[:id])
    authorize membership

    if membership.update(role: requested_role)
      redirect_to settings_team_path, notice: t("flashes.memberships.role_updated")
    else
      redirect_to settings_team_path, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    membership = policy_scope(Membership).find(params[:id])
    authorize membership
    membership.destroy!
    redirect_to settings_team_path, notice: t("flashes.memberships.removed")
  rescue ActiveRecord::RecordNotDestroyed
    redirect_to settings_team_path, alert: membership.errors.full_messages.to_sentence
  end

  private

  def requested_role
    params.dig(:membership, :role)
  end
end
