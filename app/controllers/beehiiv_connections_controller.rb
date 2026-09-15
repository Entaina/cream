class BeehiivConnectionsController < ApplicationController
  include RequiresFeature

  requires_feature :marketing_consent

  def create
    @beehiiv_connection = current_workspace.build_beehiiv_connection(connection_params.merge(user: current_user))
    authorize @beehiiv_connection
    save_connection("Beehiiv conectado.")
  end

  def update
    @beehiiv_connection = find_connection
    authorize @beehiiv_connection

    attrs = connection_params
    attrs = attrs.except(:api_key) if attrs[:api_key].blank?
    @beehiiv_connection.assign_attributes(attrs)
    save_connection("Ajustes de Beehiiv actualizados.")
  end

  def sync
    @beehiiv_connection = find_connection
    authorize @beehiiv_connection, :sync?

    unless @beehiiv_connection.connected?
      redirect_to settings_workspace_path, alert: "Configura la API key y al menos una publicación primero." and return
    end

    @beehiiv_connection.beehiiv_publications.find_each do |publication|
      BeehiivSyncJob.perform_later(publication.id)
    end
    redirect_to settings_workspace_path, notice: "Sincronización con Beehiiv iniciada."
  end

  def destroy
    @beehiiv_connection = find_connection
    authorize @beehiiv_connection
    @beehiiv_connection.destroy
    redirect_to settings_workspace_path, notice: "Beehiiv desconectado.", status: :see_other
  end

  private

  def connection_params
    params.require(:beehiiv_connection).permit(:api_key, :sync_enabled)
  end

  def find_connection
    current_workspace.beehiiv_connection || raise(ActiveRecord::RecordNotFound)
  end

  def save_connection(notice)
    if @beehiiv_connection.save
      redirect_to settings_workspace_path, notice: notice
    else
      load_settings_connections
      render "settings/workspace/show", status: :unprocessable_entity
    end
  end

  def load_settings_connections
    if CreamFeatures.enabled?(:marketing_consent)
      @beehiiv_connection = current_workspace.beehiiv_connection ||
        current_workspace.build_beehiiv_connection(user: current_user)
      @new_beehiiv_publication = @beehiiv_connection.beehiiv_publications.build if @beehiiv_connection.persisted?
    end
    return unless CreamFeatures.enabled?(:marketing_campaigns)

    @mailjet_connection = current_workspace.mailjet_connection ||
      current_workspace.build_mailjet_connection(user: current_user)
  end
end
