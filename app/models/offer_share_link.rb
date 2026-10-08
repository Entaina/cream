# Public share URL for one contact on one offer (revocable from the CRM).
class OfferShareLink < ApplicationRecord
  has_secure_token

  belongs_to :workspace
  belongs_to :offer
  belongs_to :person

  has_many :access_grants, class_name: "OfferAccessGrant", dependent: :destroy
  has_many :views, class_name: "OfferView", dependent: :nullify

  scope :active, -> { where(revoked_at: nil) }

  def active?
    revoked_at.nil?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
