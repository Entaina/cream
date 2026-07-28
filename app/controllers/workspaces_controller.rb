class WorkspacesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  after_action :verify_authorized, only: :update

  def update
    workspace = current_user.workspaces.find(params[:workspace_id])
    authorize workspace, :show?

    session[:workspace_id] = workspace.id
    redirect_to root_path
  end
end
