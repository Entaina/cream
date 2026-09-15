module Api
  module V1
    module Marketing
      class BaseController < Api::V1::BaseController
        private

        def feature_unavailable!(flag)
          label = CreamFeatures.entry(flag).label
          render json: {error: "#{label} is not available yet."}, status: :not_found
        end

        def list_limit
          ::Marketing::ApiPresenter.list_limit(params[:limit])
        end
      end
    end
  end
end
