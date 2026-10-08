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

  # URLs carry secret tokens, and offers may load third-party assets: never leak them via Referer,
  # never cache proposal content, never index portal pages.
  def apply_client_portal_headers
    response.cache_control.replace(no_store: true)
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
  end
end
