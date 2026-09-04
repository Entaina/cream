module Public
  class EmailEventsController < ApplicationController
    allow_unauthenticated_access only: :create
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :verify_webhook_token!

    def create
      return head :not_found unless CreamFeatures.enabled?(:marketing_campaigns)

      payload = JSON.parse(request.raw_post)
      Marketing::WebhookProcessor.process!(payload: payload)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def verify_webhook_token!
      expected = ENV["MAILJET_WEBHOOK_TOKEN"].to_s
      return head :unauthorized if expected.blank?

      provided = params[:token].presence ||
        request.headers["X-Mailjet-Token"].presence ||
        request.headers["X-Cream-Webhook-Token"].presence
      head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(provided.to_s, expected)
    end
  end
end
