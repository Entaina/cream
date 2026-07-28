class GmailConnectionsController < ApplicationController
  include RequiresFeature
  requires_feature :gmail_sync

  helper_method :gmail_auth_url

  def show
    @connection = current_workspace.gmail_connections.find_or_initialize_by(user: current_user)
    authorize @connection
  end

  def update
    @connection = current_workspace.gmail_connections.find_by!(user: current_user)
    authorize @connection

    attrs = connection_params
    if enabled_param?(attrs[:sync_enabled]) && !@connection.can_read_metadata?
      redirect_to gmail_connection_path, alert: "Grant inbox access before enabling reply detection." and return
    end
    if enabled_param?(attrs[:send_enabled]) && !@connection.can_send?
      redirect_to gmail_connection_path, alert: "Reconnect Gmail to grant send permission." and return
    end

    @connection.update(attrs)
    redirect_to gmail_connection_path, notice: "Gmail settings updated."
  end

  def sync
    @connection = current_workspace.gmail_connections.find_by!(user: current_user)
    authorize @connection

    unless @connection.connected?
      redirect_to gmail_connection_path, alert: "Connect Gmail first." and return
    end
    unless @connection.can_read_metadata?
      redirect_to gmail_connection_path, alert: "Grant inbox access before syncing replies." and return
    end

    GmailSyncJob.perform_later(@connection.id)
    redirect_to gmail_connection_path, notice: "Inbox sync started."
  end

  def destroy
    @connection = current_workspace.gmail_connections.find_by!(user: current_user)
    authorize @connection
    @connection.destroy
    redirect_to gmail_connection_path, notice: "Gmail disconnected.", status: :see_other
  end

  def gmail_auth_url(mode)
    "/auth/google_gmail?#{gmail_auth_query(mode)}"
  end

  private

  def connection_params
    params.require(:gmail_connection).permit(:send_enabled, :sync_enabled)
  end

  def enabled_param?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def gmail_auth_query(mode)
    base_scope = [
      "email",
      "profile",
      GmailConnection::SEND_SCOPE
    ].join(",")

    case mode.to_sym
    when :send
      { scope: base_scope }.to_query
    when :send_receive
      {
        scope: "#{base_scope},#{GmailConnection::METADATA_SCOPE}",
        include_granted_scopes: "true"
      }.to_query
    when :full
      {
        scope: "#{base_scope},#{GmailConnection::READONLY_SCOPE}",
        gmail_mode: "full",
        prompt: "consent"
      }.to_query
    else
      raise ArgumentError, "Unknown Gmail auth mode: #{mode}"
    end
  end
end
