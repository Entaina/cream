class CalendarConnectionsController < ApplicationController
  include RequiresFeature

  requires_feature :calendar_booking

  helper_method :calendar_auth_url

  def show
    @connection = current_workspace.calendar_connections.find_or_initialize_by(user: current_user)
    authorize @connection
  end

  def destroy
    @connection = current_workspace.calendar_connections.find_by!(user: current_user)
    authorize @connection
    @connection.destroy
    redirect_to calendar_connection_path, notice: t("flashes.calendar.disconnected"), status: :see_other
  end

  # Reuses the google_gmail OmniAuth route (already registered in middleware) with
  # calendar scopes — same pattern as Gmail send/receive/full modes.
  def calendar_auth_url
    "/auth/google_gmail?#{calendar_auth_query}"
  end

  private

  def calendar_auth_query
    {
      scope: (["email", "profile"] + CalendarConnection::OAUTH_SCOPES).join(","),
      calendar_mode: "1",
      prompt: "consent"
    }.to_query
  end
end
