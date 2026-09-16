module Public
  class EmailEventsController < ApplicationController
    allow_unauthenticated_access only: :create
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    skip_forgery_protection only: :create

    before_action :verify_webhook_token!

    def create
      return head :not_found unless CreamFeatures.enabled?(:marketing_campaigns)

      payload = JSON.parse(request.raw_post)
      Marketing::WebhookProcessor.process!(payload: payload, workspace: @mailjet_connection.workspace)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def verify_webhook_token!
      provided = params[:token].presence ||
        request.headers["X-Mailjet-Token"].presence ||
        request.headers["X-Cream-Webhook-Token"].presence
      return head :unauthorized if provided.blank?

      @mailjet_connection = MailjetConnection.find_by(webhook_token: provided)
      head :unauthorized unless @mailjet_connection
    end
  end
end
