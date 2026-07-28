class SessionsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if (user = User.authenticate_by(params.permit(:email_address, :password)))
      start_new_session_for user
      return if accept_pending_invitation_for(user)

      redirect_to safe_return_to(params[:return_to]) || after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private

  def accept_pending_invitation_for(user)
    token = session[:pending_invitation_token]
    return false if token.blank?

    invitation = Invitation.find_by_token(token)
    return false unless invitation&.pending?
    return false unless invitation.email_address == user.email_address

    invitation.accept_for!(user)
    session.delete(:pending_invitation_token)
    session[:workspace_id] = invitation.workspace_id
    redirect_to root_path, notice: "You joined #{invitation.workspace.name}."
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def safe_return_to(url)
    return nil if url.blank?

    uri = URI.parse(url)
    return url if uri.host.nil?
    return url if uri.host == request.host

    nil
  rescue URI::InvalidURIError
    nil
  end
end
