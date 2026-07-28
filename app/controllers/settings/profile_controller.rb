module Settings
  class ProfileController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: %i[show update]

    def show
      authorize [ :settings, :profile ]
    end

    def update
      authorize [ :settings, :profile ]

      if current_membership.update(membership_params)
        redirect_to settings_profile_path, notice: "Preferencias actualizadas."
      else
        redirect_to settings_profile_path, alert: current_membership.errors.full_messages.to_sentence
      end
    end

    private

    def membership_params
      params.require(:membership).permit(:current_pipeline_id, :sales_director_briefing_enabled)
    end
  end
end
