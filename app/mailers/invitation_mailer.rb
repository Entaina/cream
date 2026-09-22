class InvitationMailer < ApplicationMailer
  def invite(invitation, plaintext_token)
    @invitation = invitation
    @accept_url = invitation.accept_url(plaintext_token)
    @inviter_name = invitation.invited_by.name
    @workspace_name = invitation.workspace.name
    @role_label = Membership.role_label_for(invitation.role)

    with_mailer_locale(invitation.invited_by.locale) do
      @expires_at = l(invitation.expires_at, format: :long)
      mail(
        subject: t("invitation_mailer.invite.subject", workspace_name: @workspace_name),
        to: invitation.email_address
      )
    end
  end

  private

  def mailjet_workspace = @invitation.workspace
end
