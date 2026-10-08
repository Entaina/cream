module Superadmin
  class WorkspaceMembersController < BaseController
    before_action :set_workspace
    before_action :set_membership, only: %i[update destroy]

    def create
      authorize @workspace, :update?

      email = member_params[:email_address].to_s.strip.downcase
      role = member_params[:role].presence || "salesperson"
      role = "salesperson" unless Membership::ROLES.include?(role)

      user = User.find_by(email_address: email)
      if user
        membership = @workspace.memberships.build(user: user, role: role)
        if membership.save
          redirect_to superadmin_workspace_path(@workspace), notice: t("flashes.superadmin.member_added")
        else
          redirect_to superadmin_workspace_path(@workspace), alert: membership.errors.full_messages.to_sentence
        end
      else
        invitation = @workspace.invitations.build(
          email_address: email,
          role: role,
          invited_by: current_user
        )
        if invitation.save
          InvitationMailer.invite(invitation, invitation.plaintext_token).deliver_later
          flash[:notice] = t("flashes.superadmin.invitation_sent", email: email)
          flash[:invitation_link] = invitation.accept_url
          redirect_to superadmin_workspace_path(@workspace)
        else
          redirect_to superadmin_workspace_path(@workspace), alert: invitation.errors.full_messages.to_sentence
        end
      end
    end

    def update
      authorize @membership

      if @membership.update(role: member_params[:role])
        redirect_to superadmin_workspace_path(@workspace), notice: t("flashes.superadmin.member_updated")
      else
        redirect_to superadmin_workspace_path(@workspace), alert: @membership.errors.full_messages.to_sentence
      end
    end

    def destroy
      authorize @membership
      @membership.destroy!
      redirect_to superadmin_workspace_path(@workspace), notice: t("flashes.superadmin.member_removed")
    rescue ActiveRecord::RecordNotDestroyed
      redirect_to superadmin_workspace_path(@workspace), alert: @membership.errors.full_messages.to_sentence
    end

    private

    def set_workspace
      @workspace = policy_scope(Workspace).find(params[:workspace_id])
    end

    def set_membership
      @membership = policy_scope(Membership).find_by!(workspace: @workspace, id: params[:id])
    end

    def member_params
      params.require(:member).permit(:email_address, :role)
    end
  end
end
