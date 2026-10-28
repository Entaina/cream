class SegmentMembership < ApplicationRecord
  include WorkspaceScopedAssociations

  belongs_to :workspace
  belongs_to :segment
  belongs_to :person

  validates :entered_at, presence: true
  validates_same_workspace :segment, :person
  validates :person_id, uniqueness: {scope: :segment_id}
end
