require "net/http"
require "json"

# Minimal Stripe API client over Net::HTTP (same convention as Ai::Client:
# no SDK gem, so specs stub HTTP and per-workspace keys need no global config).
class StripeClient
  Error = Class.new(StandardError)
  AuthenticationError = Class.new(Error)

  API_BASE = "https://api.stripe.com/v1".freeze
  PAGE_LIMIT = 100
  # Runaway guard for the first historical import; the sync cursor advances,
  # so anything beyond the cap is picked up on the next run.
  MAX_PAGES = 50
  TIMEOUT = 30

  def initialize(api_key:)
    @api_key = api_key
  end

  # Yields each charge (as a Hash) newer than `created_after` (unix epoch),
  # oldest first, following Stripe's cursor pagination. Charges come with the
  # full Customer object expanded (fallback email/phone/address for matching).
  def list_charges(created_after: nil)
    params = {"limit" => PAGE_LIMIT, "expand[]" => "data.customer"}
    params["created[gt]"] = created_after.to_i if created_after.present?
    starting_after = nil

    MAX_PAGES.times do
      page = get_json("/charges", params.merge({"starting_after" => starting_after}.compact))
      data = Array(page["data"])
      # Stripe lists newest first; yield oldest first so the cursor advances safely.
      data.reverse_each { |charge| yield charge }
      break unless page["has_more"] && data.any?

      starting_after = data.last["id"]
    end
  end

  # Cheap credentials check used by the settings form before saving a key.
  def verify!
    get_json("/charges", {"limit" => 1})
    true
  end

  # Single charge with the customer expanded (used to backfill payloads).
  def get_charge(charge_id)
    get_json("/charges/#{charge_id}", {"expand[]" => "customer"})
  end

  private

  def get_json(path, params)
    uri = URI("#{API_BASE}#{path}")
    uri.query = URI.encode_www_form(params)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true,
      open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end

    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)

    if response.is_a?(Net::HTTPUnauthorized) || response.is_a?(Net::HTTPForbidden)
      raise AuthenticationError, "Stripe rejected the API key (#{response.code})"
    end

    raise Error, "Stripe request failed (#{response.code}): #{error_message(response.body)}"
  rescue Timeout::Error, SystemCallError, SocketError => e
    raise Error, "Stripe request failed: #{e.message}"
  end

  def error_message(body)
    JSON.parse(body).dig("error", "message") || body.to_s.truncate(200)
  rescue JSON::ParserError
    body.to_s.truncate(200)
  end
end
