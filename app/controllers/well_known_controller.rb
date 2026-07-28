# OAuth metadata discovery: RFC 8414 (authorization server) and RFC 9728 (protected resource).
class WellKnownController < ActionController::API
  def oauth_authorization_server
    render json: {
      issuer: root_url.chomp("/"),
      authorization_endpoint: oauth_authorization_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: url_for(controller: "oauth_registrations", action: "create", only_path: false),
      revocation_endpoint: oauth_revoke_url,
      scopes_supported: [ "mcp" ],
      response_types_supported: [ "code" ],
      response_modes_supported: [ "query" ],
      grant_types_supported: [ "authorization_code", "refresh_token" ],
      token_endpoint_auth_methods_supported: [ "none" ],
      code_challenge_methods_supported: [ "S256" ]
    }
  end

  def oauth_protected_resource
    render json: {
      resource: mcp_url,
      authorization_servers: [ root_url.chomp("/") ],
      scopes_supported: [ "mcp" ],
      bearer_methods_supported: [ "header" ]
    }
  end

  private

  def mcp_url = url_for(controller: "mcp", action: "handle", only_path: false)
end
