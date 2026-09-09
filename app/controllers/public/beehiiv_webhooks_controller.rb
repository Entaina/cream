module Public
  class BeehiivWebhooksController < ApplicationController
    allow_unauthenticated_access only: :create
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :load_connection!

    def create
      return head :not_found unless CreamFeatures.enabled?(:marketing_consent)

      payload = request.raw_post
      verify_signature!(payload) if @connection.webhook_signing_secret.present?

      parsed = JSON.parse(payload)
      Marketing::Beehiiv::WebhookProcessor.process!(connection: @connection, payload: parsed)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue ArgumentError
      head :unauthorized
    end

    private

    def load_connection!
      @connection = BeehiivConnection.find_by(webhook_token: params[:token].to_s)
      head :unauthorized unless @connection
    end

    def verify_signature!(payload)
      Marketing::Beehiiv::SignatureVerifier.verify!(
        payload: payload,
        headers: request.headers.to_h,
        secret: @connection.webhook_signing_secret
      )
    end
  end
end
