class Activity < ApplicationRecord
  belongs_to :workspace
  belongs_to :subject, polymorphic: true
  belongs_to :user, optional: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
end
