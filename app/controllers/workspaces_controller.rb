class WorkspacesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: :update

  def update
    workspace = if current_user.superadmin?
      Workspace.find(params[:workspace_id])
    else
      current_user.workspaces.find(params[:workspace_id])
    end
    authorize workspace, :show?

    current_user.ensure_superadmin_support_membership!(workspace) if current_user.superadmin?
    session[:workspace_id] = workspace.id
    redirect_to root_path
  end
end
