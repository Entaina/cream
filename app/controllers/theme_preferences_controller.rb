class ThemePreferencesController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def update
    if current_user.update(theme: params[:theme])
      head :ok
    else
      head :unprocessable_entity
    end
  end
end
