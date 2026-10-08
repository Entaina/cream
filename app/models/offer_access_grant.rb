# One-time email link to view an offer from a shared URL. Coming back means requesting a new
# link to the same inbox, so a forwarded email doesn't hand out lasting access.
class OfferAccessGrant < ApplicationRecord
  include OneTimeGrant

  EXPIRY = 1.hour
  MAX_PER_EMAIL_PER_HOUR = 5

  belongs_to :offer_share_link

  scope :not_revoked, -> { where(revoked_at: nil) }
  scope :for_offer, ->(offer) { joins(:offer_share_link).where(offer_share_links: { offer_id: offer.id }) }

  def self.normalize_email(email)
    email.to_s.strip.downcase
  end

  def self.issue!(share_link:, email:)
    build_with_token(offer_share_link: share_link, email: normalize_email(email))
  end

  def self.consume!(share_link:, raw_token:)
    consume_from(where(offer_share_link_id: share_link.id).not_revoked, raw_token)
  end

  def self.find_pending(share_link:, raw_token:)
    where(offer_share_link_id: share_link.id).not_revoked.pending_for(raw_token).first
  end

  def self.blocked?(offer:, email:)
    for_offer(offer).where(email: normalize_email(email)).where.not(revoked_at: nil).exists?
  end

  def self.limit_reached?(share_link:, email:)
    issued_too_often?(where(offer_share_link_id: share_link.id)) ||
      for_offer(share_link.offer).where(email: normalize_email(email))
        .where("offer_access_grants.created_at > ?", 1.hour.ago).count >= MAX_PER_EMAIL_PER_HOUR
  end

  # Revokes every link this email holds for the offer, and blocks it from requesting new ones.
  def revoke_for_offer!
    now = Time.current
    self.class.for_offer(offer_share_link.offer).where(email: email, revoked_at: nil)
      .update_all(revoked_at: now, updated_at: now)
  end

  def revoked?
    revoked_at.present?
  end
end
