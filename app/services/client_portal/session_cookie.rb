module ClientPortal
  class SessionCookie
    KEY = :client_portal
    EXPIRY = ClientPortalSession::EXPIRY

    def self.read(cookies)
      session = ClientPortalSession.find_active(token(cookies))
      return unless session

      {
        workspace_id: session.workspace_id,
        email: session.email,
        preview: session.preview?
      }
    end

    def self.write(cookies, workspace_id:, email:, preview: false)
      ClientPortalSession.revoke(token(cookies))
      raw_token = ClientPortalSession.start!(workspace_id: workspace_id, email: email, preview: preview)
      cookies.encrypted[KEY] = {
        value: raw_token,
        httponly: true,
        same_site: :lax,
        expires: EXPIRY.from_now
      }
    end

    def self.clear(cookies)
      ClientPortalSession.revoke(token(cookies))
      cookies.delete(KEY)
    end

    def self.token(cookies)
      raw = cookies.encrypted[KEY]
      return raw if raw.is_a?(String)

      legacy_token(cookies, raw) if raw.is_a?(Hash)
    end

    # Cookies that still carry workspace_id/email are keyed by their ciphertext, so signing out revokes
    # every copy of them too. Rails rejects them once their embedded expiry passes (7 days at most).
    def self.legacy_token(cookies, raw)
      workspace_id = raw["workspace_id"] || raw[:workspace_id]
      email = raw["email"] || raw[:email]
      return if workspace_id.blank? || email.blank?
      return unless Workspace.exists?(workspace_id.to_i)

      ciphertext = cookies[KEY]
      ClientPortalSession.adopt_legacy!(
        raw_token: ciphertext,
        workspace_id: workspace_id.to_i,
        email: email,
        preview: ActiveModel::Type::Boolean.new.cast(raw.key?("preview") ? raw["preview"] : raw[:preview]) == true
      )
      ciphertext
    end
    private_class_method :token, :legacy_token
  end
end
