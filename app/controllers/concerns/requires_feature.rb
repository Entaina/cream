module RequiresFeature
  extend ActiveSupport::Concern

  class_methods do
    def requires_workspace_feature(feature_key)
      before_action do
        next if current_workspace&.feature_enabled?(feature_key)

        message = CreamFeatures.unavailable_in_workspace_message(feature_key)
        if is_a?(ActionController::API)
          render json: {error: message}, status: :not_found
        else
          respond_to do |format|
            format.html { redirect_to root_path, alert: message }
            format.json { render json: {error: message}, status: :not_found }
            format.any { head :not_found }
          end
        end
      end
    end

    def requires_feature(feature_key)
      # No `only:` — the whole controller maps to one feature, and at this point
      # in the class body the action methods are not defined yet, so an `only:`
      # filter computed from `action_methods` would be empty and never fire.
      before_action do
        next if CreamFeatures.enabled?(feature_key)

        message = CreamFeatures.unavailable_message(feature_key)
        if is_a?(ActionController::API)
          render json: {error: message}, status: :not_found
        else
          respond_to do |format|
            format.html { redirect_to root_path, alert: message }
            format.json { render json: {error: message}, status: :not_found }
            format.any { head :not_found }
          end
        end
      end
    end
  end
end
