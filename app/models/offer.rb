# A commercial offer attached to a deal. The offer is a named container; its
# content (PDF/HTML) lives in numbered OfferVersions, the latest being current.
class Offer < ApplicationRecord
  belongs_to :workspace
  belongs_to :deal
  belongs_to :user

  has_many :versions, -> { order(:number) }, class_name: "OfferVersion", dependent: :destroy, inverse_of: :offer,
    validate: false # validated by the caller, so errors stay on the version

  validates :name, presence: true
  validate :deal_in_workspace

  def current_version
    versions.reorder(number: :desc).first
  end

  private

  def deal_in_workspace
    return if deal.nil? || deal.workspace_id == workspace_id

    errors.add(:deal, :must_belong_to_same_workspace)
  end
end
