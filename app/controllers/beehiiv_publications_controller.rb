class BeehiivPublicationsController < ApplicationController
  include RequiresFeature

  requires_feature :marketing_consent

  def create
    @beehiiv_connection = find_connection
    @beehiiv_publication = @beehiiv_connection.beehiiv_publications.build(publication_params)
    authorize @beehiiv_publication
    save_publication("created")
  end

  def update
    @beehiiv_connection = find_connection
    @beehiiv_publication = @beehiiv_connection.beehiiv_publications.find(params[:id])
    authorize @beehiiv_publication

    attrs = publication_params
    attrs = attrs.except(:webhook_signing_secret) if attrs[:webhook_signing_secret].blank?
    @beehiiv_publication.assign_attributes(attrs)
    save_publication("updated")
  end

  def destroy
    @beehiiv_connection = find_connection
    @beehiiv_publication = @beehiiv_connection.beehiiv_publications.find(params[:id])
    authorize @beehiiv_publication
    @beehiiv_publication.destroy
    redirect_to settings_workspace_path, notice: t("flashes.beehiiv.publication_deleted"), status: :see_other
  end

  private

  def publication_params
    params.require(:beehiiv_publication).permit(:subscription_type_id, :publication_id, :webhook_signing_secret)
  end

  def find_connection
    current_workspace.beehiiv_connection || raise(ActiveRecord::RecordNotFound)
  end

  def save_publication(action)
    if @beehiiv_publication.save
      notice_key = "flashes.beehiiv.publication_#{action}"
      if @beehiiv_connection.connected? && @beehiiv_connection.sync_enabled?
        BeehiivSyncJob.perform_later(@beehiiv_publication.id)
        notice_key = "#{notice_key}_syncing"
      end
      redirect_to settings_workspace_path, notice: t(notice_key)
    else
      load_settings_connections
      render "settings/workspace/show", status: :unprocessable_entity
    end
  end

  def load_settings_connections
    @beehiiv_connection = current_workspace.beehiiv_connection
    @new_beehiiv_publication = @beehiiv_connection.beehiiv_publications.build if @beehiiv_connection
    return unless CreamFeatures.enabled?(:marketing_campaigns)

    @mailjet_connection = current_workspace.mailjet_connection ||
      current_workspace.build_mailjet_connection(user: current_user)
  end
end
