module Settings
  class ProfileController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: %i[show update]

    def show
      authorize [:settings, :profile]
    end

    def update
      authorize [:settings, :profile]

      if params[:user].present?
        update_name
      else
        update_membership_preferences
      end
    end

    private

    def update_name
      if current_user.update(user_params)
        persist_locale_cookie(current_user.locale)
        redirect_to settings_profile_path, notice: t("profile.flashes.name_updated")
      else
        redirect_to settings_profile_path, alert: current_user.errors.full_messages.to_sentence
      end
    end

    def update_membership_preferences
      if current_membership.update(membership_params)
        redirect_to settings_profile_path, notice: t("profile.flashes.preferences_updated")
      else
        redirect_to settings_profile_path, alert: current_membership.errors.full_messages.to_sentence
      end
    end

    def user_params
      params.require(:user).permit(:name, :locale, :time_zone)
    end

    def membership_params
      params.require(:membership).permit(:current_pipeline_id, :sales_director_briefing_enabled,
        :alert_in_app, :alert_email)
    end
  end
end
