module RequiresFeature
  extend ActiveSupport::Concern

  class_methods do
    def requires_feature(feature_key)
      # No `only:` — the whole controller maps to one feature, and at this point
      # in the class body the action methods are not defined yet, so an `only:`
      # filter computed from `action_methods` would be empty and never fire.
      before_action do
        next if CreamFeatures.enabled?(feature_key)

        label = CreamFeatures.entry(feature_key).label
        message = "#{label} is not available yet."
        respond_to do |format|
          format.html { redirect_to root_path, alert: message }
          format.json { render json: { error: message }, status: :not_found }
          format.any { head :not_found }
        end
      end
    end
  end
end
