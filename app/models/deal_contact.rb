# Join between a deal and the people (contacts) involved in it.
class DealContact < ApplicationRecord
  include WorkspaceScopedAssociations

  SOURCES = %w[offer_share portal_invite].freeze

  belongs_to :deal
  belongs_to :person
  belongs_to :offer_share_link, optional: true

  validates :person_id, uniqueness: {scope: :deal_id}
  validates :source, inclusion: {in: SOURCES}, allow_nil: true
  validate :person_in_deal_workspace

  # Contacts that only came in through a shared proposal see that proposal, not the portal.
  scope :with_portal_access, -> { where.not(source: "offer_share").or(where(source: nil)) }

  def via_offer_share?
    source == "offer_share"
  end

  def via_portal_invite?
    source == "portal_invite"
  end

  after_create :track_contact_added
  after_destroy :track_contact_removed

  private

  def person_in_deal_workspace
    return unless new_record? || will_save_change_to_person_id? || will_save_change_to_deal_id?
    return if deal.nil? || person.nil?
    return if person.workspace_id == deal.workspace_id

    errors.add(:person, :must_belong_to_same_workspace)
  end

  def track_contact_added
    deal.track_activity("contacts_changed", metadata: contact_metadata("added"))
  end

  def track_contact_removed
    return if destroyed_by_association

    deal.track_activity("contacts_changed", metadata: contact_metadata("removed"))
  end

  def contact_metadata(change)
    metadata = {change: change, contact: person.display_name, contact_id: person_id}
    if via_offer_share?
      metadata[:via] = "offer_share"
      metadata[:shared_by] = offer_share_link&.person&.display_name
      metadata[:offer] = offer_share_link&.offer&.name
    elsif via_portal_invite?
      metadata[:via] = "portal_invite"
    end
    metadata
  end
end
