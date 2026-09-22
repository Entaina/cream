class LeadSubmission < ApplicationRecord
  CAPTURE_DESTINATIONS = LeadForm::DESTINATIONS.freeze

  belongs_to :workspace
  belongs_to :lead_form
  belongs_to :deal, optional: true
  belongs_to :person
  belongs_to :campaign, optional: true
  belongs_to :privacy_policy_version, optional: true
  has_one :product_interest, class_name: "Marketing::ProductInterest", dependent: :nullify

  validates :data, :metadata, presence: true
  validates :capture_destination, inclusion: {in: CAPTURE_DESTINATIONS}
  validates :submission_key, uniqueness: {scope: %i[workspace_id lead_form_id]}, allow_nil: true
  validate :deal_required_for_deal_capture

  private

  def deal_required_for_deal_capture
    return unless capture_destination == "deal"

    errors.add(:deal, :deal_required_for_capture) if deal.blank?
  end
end
