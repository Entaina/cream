class InvitationsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: %i[create destroy resend]

  def create
    invitation = current_workspace.invitations.build(
      email_address: invitation_params[:email_address],
      role: requested_role,
      invited_by: current_user
    )
    authorize invitation

    if invitation.save
      InvitationMailer.invite(invitation, invitation.plaintext_token).deliver_later
      flash[:notice] = "Invitation sent to #{invitation.email_address}."
      flash[:invitation_link] = invitation.accept_url
      redirect_to settings_team_path
    else
      redirect_to settings_team_path, alert: invitation.errors.full_messages.to_sentence
    end
  end

  def destroy
    invitation = policy_scope(Invitation).pending.find(params[:id])
    authorize invitation
    invitation.destroy!
    redirect_to settings_team_path, notice: "Invitation revoked."
  end

  def resend
    invitation = policy_scope(Invitation).pending.find(params[:id])
    authorize invitation, :resend?

    invitation.regenerate_token!
    InvitationMailer.invite(invitation, invitation.plaintext_token).deliver_later
    flash[:notice] = "Invitation resent to #{invitation.email_address}."
    flash[:invitation_link] = invitation.accept_url
    redirect_to settings_team_path
  end

  private

  def invitation_params
    params.require(:invitation).permit(:email_address)
  end

  def requested_role
    role = params.dig(:invitation, :role).presence
    Membership::ROLES.include?(role) ? role : "salesperson"
  end
end
