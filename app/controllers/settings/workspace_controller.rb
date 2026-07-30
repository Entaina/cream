module Settings
  class WorkspaceController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: %i[show update]

    def show
      authorize [ :settings, :workspace ]
    end

    def update
      authorize [ :settings, :workspace ]

      if current_workspace.update(workspace_params)
        redirect_to settings_workspace_path, notice: "Workspace updated."
      else
        redirect_to settings_workspace_path, alert: current_workspace.errors.full_messages.to_sentence
      end
    end

    private

    def workspace_params
      permitted = params.require(:workspace).permit(
        :name,
        :sales_director_enabled,
        :salespeople_can_view_all_deals,
        :salespeople_can_edit_all_deals,
        :okm_chat_enabled,
        :okm_drive_id,
        :okm_service_account_key
      )
      permitted.delete(:okm_service_account_key) if permitted[:okm_service_account_key].blank?
      permitted
    end
  end
end
