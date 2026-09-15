class ListEntry < ApplicationRecord
  belongs_to :list
  belongs_to :record, polymorphic: true

  validates :record_id, uniqueness: {scope: [:list_id, :record_type]}

  before_create { self.position ||= (list.list_entries.maximum(:position) || 0) + 1 }
end
