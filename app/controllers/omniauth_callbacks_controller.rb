class OmniauthCallbacksController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access only: %i[create failure]

  def create
    auth = request.env["omniauth.auth"]
    return connect_gmail(auth) if auth.provider == "google_gmail"

    pending_token = session[:pending_invitation_token]
    user = User.find_or_create_from_omniauth(auth, pending_invitation_token: pending_token)

    if pending_token.present?
      invitation = Invitation.find_by_token(pending_token)
      if invitation&.accepted? && invitation.email_address == user.email_address
        session[:workspace_id] = invitation.workspace_id
        session.delete(:pending_invitation_token)
      end
    end

    start_new_session_for user
    redirect_to after_authentication_url
  rescue ActiveRecord::RecordInvalid
    redirect_to new_session_path, alert: t("flashes.oauth.google_sign_in_failed")
  end

  def failure
    alert = if params[:message] == "csrf_detected"
      t("flashes.oauth.sign_in_session_expired")
    else
      t("flashes.oauth.google_sign_in_failed")
    end

    redirect_to new_session_path, alert: alert
  end

  private

  # Gmail connection callback (provider :google_gmail): stores the OAuth tokens
  # against the signed-in user's workspace instead of starting a session.
  def connect_calendar(auth)
    resume_session
    unless current_user
      redirect_to new_session_path, alert: t("flashes.oauth.calendar_sign_in_first") and return
    end

    unless CreamFeatures.enabled?(:calendar_booking)
      redirect_to root_path, alert: t("flashes.oauth.calendar_booking_disabled") and return
    end

    workspace = current_user.active_workspace(session_workspace_id: session[:workspace_id])
    connection = workspace.calendar_connections.find_or_initialize_by(user: current_user)
    connection.assign_oauth_credentials(auth)

    if connection.save
      redirect_to calendar_connection_path, notice: t("flashes.oauth.calendar_connected", email: connection.email)
    else
      redirect_to calendar_connection_path, alert: t("flashes.oauth.calendar_connect_failed")
    end
  end

  def connect_gmail(auth)
    # This action allows unauthenticated access (for sign-in), so the session
    # isn't resumed automatically — do it here to identify who is connecting.
    resume_session
    unless current_user
      redirect_to new_session_path, alert: t("flashes.oauth.gmail_sign_in_first") and return
    end

    if calendar_connect_request?
      connect_calendar(auth)
      return
    end

    workspace = current_user.active_workspace(session_workspace_id: session[:workspace_id])
    connection = workspace.gmail_connections.find_or_initialize_by(user: current_user)
    mode = request.env.dig("omniauth.params", "gmail_mode").presence || params[:gmail_mode]
    connection.assign_oauth_credentials(auth, mode: mode)

    if connection.save
      redirect_to gmail_connection_path, notice: t("flashes.oauth.gmail_connected", email: connection.email)
    else
      redirect_to gmail_connection_path, alert: t("flashes.oauth.gmail_connect_failed")
    end
  end

  def calendar_connect_request?
    value = request.env.dig("omniauth.params", "calendar_mode").presence || params[:calendar_mode]
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
