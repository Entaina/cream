class SmtpConnectionsController < ApplicationController
  def create
    @smtp_connection = current_workspace.build_smtp_connection(connection_params.merge(user: current_user))
    authorize @smtp_connection
    save_connection(t("flashes.smtp.connected"))
  end

  def update
    @smtp_connection = find_connection
    authorize @smtp_connection

    attrs = connection_params
    attrs = attrs.except(:password) if attrs[:password].blank?
    @smtp_connection.assign_attributes(attrs)
    save_connection(t("flashes.smtp.updated"))
  end

  def destroy
    @smtp_connection = find_connection
    authorize @smtp_connection
    @smtp_connection.destroy
    redirect_to settings_workspace_path, notice: t("flashes.smtp.disconnected"), status: :see_other
  end

  private

  def connection_params
    params.require(:smtp_connection).permit(
      :address, :port, :user_name, :password, :domain, :authentication,
      :enable_starttls_auto, :from_email, :from_name, :sender_domain_validated
    )
  end

  def find_connection
    current_workspace.smtp_connection || raise(ActiveRecord::RecordNotFound)
  end

  def save_connection(notice)
    if @smtp_connection.save
      redirect_to settings_workspace_path, notice: notice
    else
      render "settings/workspace/show", status: :unprocessable_entity
    end
  end
end
