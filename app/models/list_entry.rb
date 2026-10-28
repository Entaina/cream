class ListEntry < ApplicationRecord
  include WorkspaceScopedAssociations

  belongs_to :list
  belongs_to :record, polymorphic: true

  validates :record_id, uniqueness: {scope: [:list_id, :record_type]}
  validate :record_in_list_workspace

  before_create { self.position ||= (list.list_entries.maximum(:position) || 0) + 1 }

  private

  def record_in_list_workspace
    return unless workspace_link_changing?(:record) || will_save_change_to_list_id?
    return if list.nil? || record.nil?

    record_ws = record.try(:workspace_id)
    return if record_ws.nil?

    return if record_ws == list.workspace_id

    errors.add(:record, :must_belong_to_same_workspace)
  end

  def validation_workspace_id
    list&.workspace_id
  end
end
