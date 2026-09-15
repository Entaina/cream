class MailjetConnectionsController < ApplicationController
  include RequiresFeature

  requires_feature :marketing_campaigns

  def create
    @mailjet_connection = current_workspace.build_mailjet_connection(connection_params.merge(user: current_user))
    authorize @mailjet_connection
    save_connection("Mailjet conectado.")
  end

  def update
    @mailjet_connection = find_connection
    authorize @mailjet_connection

    attrs = connection_params
    attrs = attrs.except(:api_key) if attrs[:api_key].blank?
    attrs = attrs.except(:secret_key) if attrs[:secret_key].blank?
    @mailjet_connection.assign_attributes(attrs)
    save_connection("Ajustes de Mailjet actualizados.")
  end

  def destroy
    @mailjet_connection = find_connection
    authorize @mailjet_connection
    @mailjet_connection.destroy
    redirect_to settings_workspace_path, notice: "Mailjet desconectado.", status: :see_other
  end

  private

  def connection_params
    params.require(:mailjet_connection).permit(:api_key, :secret_key, :from_email, :from_name, :transactional_enabled)
  end

  def find_connection
    current_workspace.mailjet_connection || raise(ActiveRecord::RecordNotFound)
  end

  def save_connection(notice)
    if @mailjet_connection.save
      redirect_to settings_workspace_path, notice: notice
    else
      render "settings/workspace/show", status: :unprocessable_entity
    end
  end
end
