class DealPortalAccessGrant < ApplicationRecord
  include OneTimeGrant

  EXPIRY = 24.hours

  belongs_to :deal_portal_invite_link

  def self.issue!(invite_link:, email:)
    build_with_token(deal_portal_invite_link: invite_link, email: OfferAccessGrant.normalize_email(email))
  end

  def self.consume!(invite_link:, raw_token:)
    consume_from(where(deal_portal_invite_link_id: invite_link.id), raw_token)
  end

  def self.find_pending(invite_link:, raw_token:)
    where(deal_portal_invite_link_id: invite_link.id).pending_for(raw_token).first
  end

  def self.limit_reached?(invite_link:)
    issued_too_often?(where(deal_portal_invite_link_id: invite_link.id))
  end
end
