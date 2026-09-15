class PersonEmail < ApplicationRecord
  belongs_to :person
  belongs_to :workspace

  validates :address, presence: true, format: {with: URI::MailTo::EMAIL_REGEXP}
  validate :address_unique_for_person
  validate :person_belongs_to_workspace

  before_validation :normalize_address
  before_save :demote_other_primaries, if: :primary?
  after_save :sync_person_email_column
  after_destroy :sync_person_email_column

  scope :ordered, -> { order(primary: :desc, created_at: :asc) }

  private

  def normalize_address
    self.address = address.to_s.strip.downcase.presence
  end

  def address_unique_for_person
    return if address.blank? || person.nil?

    scope = person.person_emails.where("LOWER(TRIM(address)) = ?", address)
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    errors.add(:address, "is already on this contact")
  end

  def person_belongs_to_workspace
    return if person.nil? || workspace.nil?
    return if person.workspace_id == workspace_id

    errors.add(:person, "must belong to the same workspace")
  end

  def demote_other_primaries
    person.person_emails.where.not(id: id).update_all(primary: false)
  end

  def sync_person_email_column
    return if person.destroyed?

    primary_address = person.person_emails.where(primary: true).pick(:address)
    primary_address ||= person.person_emails.order(:created_at).pick(:address)
    person.update_column(:email, primary_address) if person.email != primary_address
  end
end
