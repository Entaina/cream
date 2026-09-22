# Join between a deal and the people (contacts) involved in it.
class DealContact < ApplicationRecord
  belongs_to :deal
  belongs_to :person

  validates :person_id, uniqueness: {scope: :deal_id}

  after_create :track_contact_added
  after_destroy :track_contact_removed

  private

  def track_contact_added
    deal.track_activity("contacts_changed", metadata: contact_metadata("added"))
  end

  def track_contact_removed
    return if destroyed_by_association

    deal.track_activity("contacts_changed", metadata: contact_metadata("removed"))
  end

  def contact_metadata(change)
    {change: change, contact: person.display_name, contact_id: person_id}
  end
end
