module Api
  module V1
    class BaseController < ActionController::API
      include Pundit::Authorization
      include RequiresFeature
      requires_feature :api_v1

      rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

      before_action :authenticate_api_request!

      private

      def authenticate_api_request!
        token = bearer_token
        return head :unauthorized if token.blank?

        if token.start_with?(ApiToken::TOKEN_PREFIX)
          api_token = ApiToken.authenticate(token)
          return head :unauthorized unless api_token
          return head :forbidden if requested_workspace_id.present? &&
            requested_workspace_id.to_i != api_token.workspace_id

          @current_user = api_token.user
          @current_workspace = api_token.workspace
        else
          access_token = Doorkeeper::AccessToken.by_token(token)
          return head :unauthorized unless access_token&.accessible?
          return head :unauthorized unless access_token.includes_scope?(:api)

          @current_user = User.find_by(id: access_token.resource_owner_id)
          return head :unauthorized unless @current_user

          @current_workspace = if requested_workspace_id.present?
            @current_user.workspaces.find_by(id: requested_workspace_id)
          else
            @current_user.default_workspace
          end
          head(requested_workspace_id.present? ? :forbidden : :unauthorized) unless @current_workspace
        end
      end

      def requested_workspace_id
        request.headers["X-Cream-Workspace-Id"].presence
      end

      def bearer_token
        authorization = request.authorization.to_s
        return nil unless authorization.start_with?("Bearer ")

        authorization.delete_prefix("Bearer ").strip.presence
      end

      def current_user = @current_user
      def current_workspace = @current_workspace

      def pundit_user
        UserContext.new(user: current_user, workspace: current_workspace)
      end

      def render_forbidden
        render json: { error: "Forbidden" }, status: :forbidden
      end
    end
  end
end
