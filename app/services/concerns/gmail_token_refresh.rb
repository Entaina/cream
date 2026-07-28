require "net/http"
require "json"

# Shared OAuth token refresh for Gmail API clients (sender, reader, sync).
module GmailTokenRefresh
  TOKEN_URI = URI("https://oauth2.googleapis.com/token")
  TOKENINFO_URI = URI("https://www.googleapis.com/oauth2/v3/tokeninfo")

  def ensure_access_token!(connection)
    raise GmailSender::Error, "Gmail not connected" unless connection.connected?
    raise GmailSender::Error, "missing refresh token" if connection.refresh_token.blank?

    refresh_access_token!(connection) if connection.expired?
    connection.access_token
  end

  # Ensures the access token can read the inbox (metadata or readonly scope).
  # Refreshes when expired or when the cached token lacks read scopes after
  # incremental OAuth (common when granted_scopes in DB was updated but the
  # refresh token still only authorizes send).
  def ensure_sync_access_token!(connection)
    raise GmailReader::Error, "Gmail not connected" unless connection.connected?
    raise GmailReader::Error, "missing refresh token" if connection.refresh_token.blank?

    refresh_access_token!(connection) if connection.expired? || !token_can_read_inbox?(connection)
    unless token_can_read_inbox?(connection)
      raise GmailReader::Error,
        "Gmail token missing inbox read permission — use Enable reply detection / full reply logging again, or disconnect and reconnect."
    end

    connection.access_token
  end

  def refresh_access_token!(connection)
    response = post_form(TOKEN_URI, {
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      refresh_token: connection.refresh_token,
      grant_type: "refresh_token"
    })
    raise GmailSender::Error, "token refresh failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    connection.update!(
      access_token: data["access_token"],
      expires_at: Time.current + data.fetch("expires_in", 3600).to_i.seconds
    )
  end

  private

  def token_can_read_inbox?(connection)
    fetch_token_scopes(connection.access_token).any? do |scope|
      scope == GmailConnection::METADATA_SCOPE || scope == GmailConnection::READONLY_SCOPE
    end
  end

  def fetch_token_scopes(access_token)
    return [] if access_token.blank?

    uri = TOKENINFO_URI.dup
    uri.query = URI.encode_www_form(access_token: access_token)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.get(uri) }
    data = JSON.parse(response.body)
    return [] if data["error"].present?

    data["scope"].to_s.split
  rescue JSON::ParserError
    []
  end

  def post_form(uri, payload)
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(payload)
    execute(uri, request)
  end

  def get_json(uri, bearer:)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    execute(uri, request)
  end

  def post_json(uri, payload, bearer:)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{bearer}"
    request["Content-Type"] = "application/json"
    request.body = payload.to_json
    execute(uri, request)
  end

  def execute(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
  end
end
