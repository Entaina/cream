# Ensures belongs_to targets belong to the same workspace.
module WorkspaceScopedAssociations
  extend ActiveSupport::Concern

  class_methods do
    def validates_same_workspace(*associations, **options)
      associations.each do |association|
        validate(options) { validate_belongs_to_same_workspace(association) }
      end
    end

    def validates_polymorphic_same_workspace(association, **options)
      validate(options) { validate_polymorphic_same_workspace(association) }
    end
  end

  private

  def validation_workspace_id
    if respond_to?(:workspace_id) && workspace_id.present?
      workspace_id
    elsif respond_to?(:deal) && deal.present?
      deal.workspace_id
    elsif respond_to?(:booking_page) && booking_page.present?
      booking_page.workspace_id
    end
  end

  # Only links being created or changed are checked, so records saved before these
  # validations existed can still be edited.
  def workspace_link_changing?(association)
    return true if new_record?

    reflection = self.class.reflect_on_association(association)
    keys = [reflection.foreign_key.to_s]
    keys << reflection.foreign_type.to_s if reflection.polymorphic?
    keys << "workspace_id" if has_attribute?(:workspace_id)
    keys.any? { |key| will_save_change_to_attribute?(key) }
  end

  def validate_belongs_to_same_workspace(association)
    return unless workspace_link_changing?(association)

    record = public_send(association)
    return if record.nil?

    ws_id = validation_workspace_id
    return if ws_id.nil?

    assoc_ws = record.try(:workspace_id)
    return if assoc_ws.nil?

    return if assoc_ws == ws_id

    errors.add(association, :must_belong_to_same_workspace)
  end

  def validate_polymorphic_same_workspace(association)
    return unless workspace_link_changing?(association)

    record = public_send(association)
    return if record.nil?

    ws_id = validation_workspace_id
    return if ws_id.nil?

    assoc_ws = record.try(:workspace_id)
    return if assoc_ws.nil?

    return if assoc_ws == ws_id

    errors.add(association, :must_belong_to_same_workspace)
  end
end
