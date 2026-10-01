require "net/http"
require "json"

# Shared OAuth token refresh for Google API clients (Gmail, Calendar, etc.).
module GoogleOauthTokenRefresh
  TOKEN_URI = URI("https://oauth2.googleapis.com/token")
  TIMEOUT = 8

  def ensure_access_token!(connection)
    raise GoogleCalendar::Error, I18n.t("booking.errors.google_not_connected") unless connection.connected?
    raise GoogleCalendar::Error, I18n.t("booking.errors.missing_refresh_token") if connection.refresh_token.blank?

    refresh_access_token!(connection) if connection.expired?
    connection.access_token
  end

  def refresh_access_token!(connection)
    response = post_form(TOKEN_URI, {
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      refresh_token: connection.refresh_token,
      grant_type: "refresh_token"
    })
    raise GoogleCalendar::Error, I18n.t("booking.errors.token_refresh_failed", code: response.code) unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    connection.update!(
      access_token: data["access_token"],
      expires_at: Time.current + data.fetch("expires_in", 3600).to_i.seconds
    )
  end

  private

  def post_form(uri, payload)
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(payload)
    execute(uri, request)
  end

  def post_json(uri, payload, bearer:)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    request["Content-Type"] = "application/json"
    request.body = payload.to_json
    execute(uri, request)
  end

  def get_json(uri, bearer:)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    execute(uri, request)
  end

  def delete_json(uri, bearer:)
    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    execute(uri, request)
  end

  def patch_json(uri, payload, bearer:)
    request = Net::HTTP::Patch.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    request["Content-Type"] = "application/json"
    request.body = payload.to_json
    execute(uri, request)
  end

  def execute(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT, write_timeout: TIMEOUT) do |http|
      http.request(request)
    end
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise GoogleCalendar::Error, I18n.t("booking.errors.timeout")
  end
end
