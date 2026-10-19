# A commercial offer attached to a deal. The offer is a named container; its
# content (PDF/HTML) lives in numbered OfferVersions, the latest being current.
class Offer < ApplicationRecord
  belongs_to :workspace
  belongs_to :deal
  belongs_to :user

  has_many :versions, -> { order(:number) }, class_name: "OfferVersion", dependent: :destroy, inverse_of: :offer,
    validate: false # validated by the caller, so errors stay on the version
  has_many :views, class_name: "OfferView", dependent: :destroy
  has_many :share_links, class_name: "OfferShareLink", dependent: :destroy

  validates :name, presence: true

  scope :visible_to_contact, ->(workspace, email) {
    normalized = OfferAccessGrant.normalize_email(email)
    next none if normalized.blank?

    person_ids = workspace.people.with_email(normalized).select(:id)
    where(workspace_id: workspace.id)
      .where(deal_id: DealContact.with_portal_access.where(person_id: person_ids).select(:deal_id))
      .where(id: OfferVersion.published.select(:offer_id))
  }
  validate :deal_in_workspace

  # Latest version, draft or not: what the sales team previews in the CRM.
  def current_version
    versions.reorder(number: :desc).first
  end

  # Latest published version: the only one clients (portal, shared links) can see.
  def client_version
    versions.published.reorder(number: :desc).first
  end

  private

  def deal_in_workspace
    return if deal.nil? || deal.workspace_id == workspace_id

    errors.add(:deal, :must_belong_to_same_workspace)
  end
end
