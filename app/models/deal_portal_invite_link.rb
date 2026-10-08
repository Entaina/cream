# Public invite URL for a deal: recipient verifies email, becomes a deal contact, and enters the client portal.
class DealPortalInviteLink < ApplicationRecord
  has_secure_token

  belongs_to :workspace
  belongs_to :deal

  has_many :access_grants, class_name: "DealPortalAccessGrant", dependent: :destroy

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
