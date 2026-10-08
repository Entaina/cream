# Records when a contact opens an offer from the client portal or a shared link.
class OfferView < ApplicationRecord
  belongs_to :workspace
  belongs_to :offer
  belongs_to :offer_version
  belongs_to :person
  belongs_to :offer_share_link, optional: true

  validates :viewed_at, presence: true

  scope :newest_first, -> { order(viewed_at: :desc) }
end
