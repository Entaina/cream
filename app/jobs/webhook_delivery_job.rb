class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  def perform(webhook_id, event, payload)
    webhook = Webhook.find(webhook_id)
    delivery = webhook.webhook_deliveries.create!(event: event, payload: payload, status: "pending")

    uri = URI.parse(webhook.url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["X-Cream-Event"] = event
    request["X-Cream-Signature"] = signature(webhook.secret, payload) if webhook.secret.present?
    request.body = payload.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end

    delivery.update!(
      response_code: response.code.to_i,
      response_body: response.body.to_s.truncate(1000),
      status: response.is_a?(Net::HTTPSuccess) ? "delivered" : "failed"
    )
  rescue StandardError => e
    delivery&.update!(status: "failed", response_body: e.message)
  end

  private

  def signature(secret, payload)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload.to_json)
  end
end
