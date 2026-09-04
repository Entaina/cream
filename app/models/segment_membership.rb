class SegmentMembership < ApplicationRecord
  belongs_to :workspace
  belongs_to :segment
  belongs_to :person

  validates :entered_at, presence: true
  validates :person_id, uniqueness: { scope: :segment_id }
end
