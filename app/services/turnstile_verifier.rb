require "net/http"

# Optional invisible captcha (Cloudflare Turnstile) for public lead forms.
# Enabled only when TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY are set.
class TurnstileVerifier
  VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  def self.enabled?
    site_key.present? && secret_key.present?
  end

  def self.site_key = ENV["TURNSTILE_SITE_KEY"]
  def self.secret_key = ENV["TURNSTILE_SECRET_KEY"]

  def self.valid?(token:, ip: nil)
    return false if token.blank?

    response = Net::HTTP.post_form(
      VERIFY_URI,
      "secret" => secret_key,
      "response" => token,
      "remoteip" => ip
    )
    JSON.parse(response.body)["success"] == true
  rescue StandardError => e
    # Fail open: an outage at Cloudflare must not block legitimate leads.
    Rails.logger.warn("Turnstile verification failed: #{e.class} #{e.message}")
    true
  end
end
