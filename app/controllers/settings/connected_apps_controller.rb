module Settings
  class ConnectedAppsController < ApplicationController
    def show
      authorize [:settings, :connected_app]
      @connected_apps = active_tokens
        .joins(:application)
        .includes(:application)
        .order(created_at: :desc)
        .group_by(&:application)
    end

    def destroy
      authorize [:settings, :connected_app]
      application = Doorkeeper::Application.where(id: active_tokens.select(:application_id)).find(params[:id])
      ActiveRecord::Base.transaction do
        Doorkeeper::AccessToken.revoke_all_for(application.id, current_user)
        Doorkeeper::AccessGrant.revoke_all_for(application.id, current_user)
      end
      redirect_to settings_connected_apps_path, notice: t("settings.connected_apps.revoked"), status: :see_other
    end

    private

    def active_tokens
      Doorkeeper::AccessToken.where(resource_owner_id: current_user.id, revoked_at: nil).where.not(application_id: nil)
    end
  end
end
