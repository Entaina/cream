class SidebarPreferencesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def update
    current_user.update_sidebar_prefs!(
      order: sidebar_preference_params[:order] || [],
      hidden: sidebar_preference_params[:hidden] || []
    )

    head :ok
  end

  private

  def sidebar_preference_params
    (params[:sidebar_preference] || params).permit(order: [], hidden: [])
  end
end
