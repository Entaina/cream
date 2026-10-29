# frozen_string_literal: true

# OAuth2 provider for the Cream MCP server (authorization code + PKCE, public clients).
Doorkeeper.configure do
  orm :active_record

  # Authenticate the resource owner with Cream's session cookie (Rails 8 auth).
  resource_owner_authenticator do
    if (session_record = Session.find_by(id: cookies.signed[:session_id]))
      session_record.user
    else
      session[:return_to_after_authenticating] = request.fullpath
      redirect_to(new_session_url)
    end
  end

  # Authorization + consent pages render inside the app (gives us auth helpers and layout).
  base_controller "::ApplicationController"

  default_scopes :mcp
  optional_scopes :api
  enforce_configured_scopes

  grant_flows %w[authorization_code]
  use_refresh_token
  access_token_expires_in 7.days

  # MCP clients are public clients: PKCE required, no client secret.
  force_pkce
  pkce_code_challenge_methods %w[S256]

  forbid_redirect_uri do |uri|
    %w[javascript vbscript data].include?(uri.scheme.to_s.downcase)
  end

  # RFC 8252: native/CLI clients use HTTP loopback redirects.
  # Require HTTPS for everything else.
  force_ssl_in_redirect_uri do |uri|
    !%w[localhost 127.0.0.1 ::1].include?(uri.host&.delete_prefix("[")&.delete_suffix("]"))
  end

  # Issued tokens are stored hashed.
  hash_token_secrets
  hash_application_secrets
end

# Doorkeeper resolves layouts/doorkeeper/application from the gem (Bootstrap, no Tailwind).
# Use the main app layout so OAuth consent matches the Cream design system.
Rails.application.config.to_prepare do
  Doorkeeper::AuthorizationsController.layout "application"
  Doorkeeper::AuthorizationsController.rate_limit to: 30, within: 1.minute, prepend: true
  Doorkeeper::TokensController.rate_limit to: 30, within: 1.minute, only: :create, prepend: true
end
