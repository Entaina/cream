# RFC 7591 dynamic client registration, as required by the MCP authorization spec.
# MCP clients (Claude, inspector, etc.) POST here to obtain a client_id before the
# authorization code + PKCE flow. Clients are registered as public (no secret).
class OauthRegistrationsController < ActionController::API
  rate_limit to: 20, within: 1.minute, only: :create

  def create
    payload = params.permit(:client_name, :scope, redirect_uris: [])
    redirect_uris = Array(payload[:redirect_uris]).map(&:to_s).select(&:present?)
    scope = payload[:scope].presence || "mcp"
    allowed_scopes = %w[mcp api]

    return render_error("invalid_redirect_uri", "redirect_uris is required") if redirect_uris.empty?
    return render_error("invalid_scope", "scope must be one of: #{allowed_scopes.join(", ")}") unless allowed_scopes.include?(scope)

    application = Doorkeeper::Application.new(
      name: payload[:client_name].presence || "#{scope} client",
      redirect_uri: redirect_uris.join("\n"),
      confidential: false,
      scopes: scope
    )

    if application.save
      render json: {
        client_id: application.uid,
        client_id_issued_at: application.created_at.to_i,
        client_name: application.name,
        redirect_uris: redirect_uris,
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        token_endpoint_auth_method: "none",
        scope: scope
      }, status: :created
    else
      render_error("invalid_client_metadata", application.errors.full_messages.join(", "))
    end
  end

  private

  def render_error(code, description)
    render json: {error: code, error_description: description}, status: :bad_request
  end
end
