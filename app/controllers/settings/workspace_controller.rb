module Settings
  class WorkspaceController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: %i[show update]

    def show
      authorize [:settings, :workspace]
      load_mailjet_connection
      load_smtp_connection
      load_beehiiv_connection
      load_public_layout_templates
    end

    def update
      authorize [:settings, :workspace]

      if current_workspace.update(workspace_params)
        redirect_to settings_workspace_path, notice: t("flashes.settings.workspace_updated")
      else
        redirect_to settings_workspace_path, alert: current_workspace.errors.full_messages.to_sentence
      end
    end

    private

    def workspace_params
      permitted = params.require(:workspace).permit(
        :name,
        :time_zone,
        :sales_director_enabled,
        :salespeople_can_view_all_deals,
        :salespeople_can_edit_all_deals,
        :okm_chat_enabled,
        :okm_drive_id,
        :okm_service_account_key,
        :reports_enabled,
        :marketing_attribution_enabled,
        :lead_scoring_enabled,
        :webhooks_enabled,
        :custom_fields_enabled,
        :ga_measurement_id,
        :public_layout_template_id,
        :client_portal_layout_template_id
      )
      permitted.delete(:okm_service_account_key) if permitted[:okm_service_account_key].blank?
      permitted
    end

    def load_mailjet_connection
      return unless CreamFeatures.enabled?(:marketing_campaigns)

      @mailjet_connection = current_workspace.mailjet_connection ||
        current_workspace.build_mailjet_connection(user: current_user)
    end

    def load_smtp_connection
      @smtp_connection = current_workspace.smtp_connection ||
        current_workspace.build_smtp_connection(user: current_user)
    end

    def load_public_layout_templates
      return unless CreamFeatures.enabled?(:calendar_booking) || CreamFeatures.enabled?(:client_portal)

      @public_layout_templates = current_workspace.lead_form_templates.public_layouts.ordered
    end

    def load_beehiiv_connection
      return unless CreamFeatures.enabled?(:marketing_consent)

      @beehiiv_connection = current_workspace.beehiiv_connection ||
        current_workspace.build_beehiiv_connection(user: current_user)
      @new_beehiiv_publication = @beehiiv_connection.beehiiv_publications.build if @beehiiv_connection.persisted?
    end
  end
end
