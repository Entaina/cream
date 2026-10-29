module Public
  class BeehiivWebhooksController < ApplicationController
    allow_unauthenticated_access only: :create
    # Beehiiv can't send a CSRF token; the Svix signature authenticates the request.
    skip_forgery_protection only: :create
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :load_publication!

    def create
      return head :not_found unless CreamFeatures.enabled?(:marketing_consent)

      return head :unauthorized if @publication.webhook_signing_secret.blank?

      payload = request.raw_post
      verify_signature!(payload)

      parsed = JSON.parse(payload)
      Marketing::Beehiiv::WebhookProcessor.process!(publication: @publication, payload: parsed)
      head :ok
    rescue JSON::ParserError
      head :bad_request
    rescue ArgumentError
      head :unauthorized
    end

    private

    def load_publication!
      @publication = BeehiivPublication.find_by(webhook_token: params[:token].to_s)
      head :unauthorized unless @publication
    end

    def verify_signature!(payload)
      Marketing::Beehiiv::SignatureVerifier.verify!(
        payload: payload,
        headers: request.headers.to_h,
        secret: @publication.webhook_signing_secret
      )
    end
  end
end
