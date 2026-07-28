module Settings
  class TeamController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: %i[show update]

    def show
      authorize [ :settings, :team ]

      @memberships = policy_scope(Membership).order(:created_at)
      @pending_invitations = policy_scope(Invitation).pending.order(created_at: :desc)
      @admin = pundit_user.admin?
    end

    def update
      authorize current_workspace, :update?

      if current_workspace.update(workspace_params)
        redirect_to settings_team_path, notice: "Workspace updated."
      else
        redirect_to settings_team_path, alert: current_workspace.errors.full_messages.to_sentence
      end
    end

    private

    def workspace_params
      params.require(:workspace).permit(:name, :sales_director_enabled)
    end
  end
end
