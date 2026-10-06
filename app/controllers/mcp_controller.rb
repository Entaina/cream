# MCP server endpoint (Streamable HTTP transport). Authenticated via Bearer token
# (Cream API token or Doorkeeper OAuth access token with scope `mcp`).
class McpController < ActionController::API
  before_action :authenticate_mcp_request!

  def handle
    server = CreamMcp.server_for(user: @mcp_user, workspace: @mcp_workspace)
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(
      server,
      stateless: true,
      enable_json_response: true,
      allowed_hosts: mcp_allowed_hosts
    )
    status, headers, body = transport.handle_request(request)

    headers.each { |key, value| response.headers[key] = value }

    content = body.is_a?(Array) ? body.first : nil
    if content.present?
      render plain: content, status: status, content_type: headers["Content-Type"] || "application/json"
    else
      head status
    end
  end

  def method_not_allowed
    head :method_not_allowed
  end

  private

  def authenticate_mcp_request!
    token = bearer_token
    return unauthorized! if token.blank?

    if token.start_with?(ApiToken::TOKEN_PREFIX)
      api_token = ApiToken.authenticate(token)
      return unauthorized! unless api_token

      @mcp_user = api_token.user
      @mcp_workspace = api_token.workspace
    else
      access_token = Doorkeeper::AccessToken.by_token(token)
      return unauthorized! unless access_token&.accessible?
      return unauthorized! unless access_token.includes_scope?(:mcp)

      @mcp_user = User.find_by(id: access_token.resource_owner_id)
      return unauthorized! unless @mcp_user

      @mcp_workspace = @mcp_user.default_workspace
      return unauthorized! unless @mcp_workspace
    end

    set_request_actor!
  end

  def mcp_allowed_hosts
    hosts = []
    if ENV["CREAM_APP_URL"].present?
      host = URI.parse(ENV["CREAM_APP_URL"]).host
      hosts << host if host.present?
    end
    hosts << ENV["CREAM_DOMAIN"].strip if ENV["CREAM_DOMAIN"].present?
    hosts.uniq
  end

  def set_request_actor!
    Current.user = @mcp_user
    Current.workspace = @mcp_workspace
    PaperTrail.request.whodunnit = @mcp_user.id.to_s
  end

  def bearer_token
    authorization = request.authorization.to_s
    return nil unless authorization.start_with?("Bearer ")

    authorization.delete_prefix("Bearer ").strip.presence
  end

  def unauthorized!
    resource_metadata = url_for(controller: "well_known", action: "oauth_protected_resource", only_path: false)
    response.headers["WWW-Authenticate"] = %(Bearer resource_metadata="#{resource_metadata}")
    head :unauthorized
  end
end
