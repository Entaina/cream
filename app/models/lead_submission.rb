class LeadSubmission < ApplicationRecord
  belongs_to :workspace
  belongs_to :lead_form
  belongs_to :deal
  belongs_to :person
  belongs_to :campaign, optional: true

  validates :data, :metadata, presence: true
end
