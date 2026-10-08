module ClientPortal
  class SessionCookie
    KEY = :client_portal
    EXPIRY = 7.days

    def self.read(cookies)
      raw = cookies.encrypted[KEY]
      return unless raw.is_a?(Hash)

      workspace_id = raw["workspace_id"] || raw[:workspace_id]
      email = raw["email"] || raw[:email]
      return if workspace_id.blank? || email.blank?

      { workspace_id: workspace_id.to_i, email: OfferAccessGrant.normalize_email(email) }
    end

    def self.write(cookies, workspace_id:, email:)
      cookies.encrypted[KEY] = {
        value: { workspace_id: workspace_id, email: OfferAccessGrant.normalize_email(email) },
        httponly: true,
        same_site: :lax,
        expires: EXPIRY.from_now
      }
    end

    def self.clear(cookies)
      cookies.delete(KEY)
    end
  end
end
