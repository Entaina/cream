module Api
  module V1
    module Marketing
      class BaseController < Api::V1::BaseController
        private

        def feature_unavailable!(flag)
          render json: {error: CreamFeatures.unavailable_message(flag)}, status: :not_found
        end

        def list_limit
          ::Marketing::ApiPresenter.list_limit(params[:limit])
        end
      end
    end
  end
end
