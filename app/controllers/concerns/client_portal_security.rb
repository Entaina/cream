# Shared hardening for the public client portal and offer share pages.
module ClientPortalSecurity
  extend ActiveSupport::Concern

  included do
    before_action :ensure_client_portal_feature!
    before_action :apply_client_portal_headers
  end

  private

  def ensure_client_portal_feature!
    head :not_found unless CreamFeatures.enabled?(:client_portal)
  end

  # Tokens stay out of cross-origin Referer, and pages are not cached or indexed.
  # same-origin, not no-referrer: no-referrer makes the browser send Origin: null,
  # and Rails then rejects the confirm POST with 422.
  def apply_client_portal_headers
    response.cache_control.replace(no_store: true)
    response.headers["Referrer-Policy"] = "same-origin"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
