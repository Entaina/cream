class InvitationMailer < ApplicationMailer
  def invite(invitation, plaintext_token)
    @invitation = invitation
    @accept_url = invitation.accept_url(plaintext_token)
    @inviter_name = invitation.invited_by.name
    @workspace_name = invitation.workspace.name

    mail subject: "Join #{@workspace_name} on Cream", to: invitation.email_address
  end
end
