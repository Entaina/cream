class LeadSubmission < ApplicationRecord
  belongs_to :workspace
  belongs_to :lead_form
  belongs_to :deal
  belongs_to :person

  validates :data, :metadata, presence: true
end
