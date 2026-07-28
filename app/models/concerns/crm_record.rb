# Shared behaviour for the three core record types (Company, Person, Deal).
module CrmRecord
  extend ActiveSupport::Concern

  included do
    include Trackable
    include CustomFields
    include MagicColumns

    belongs_to :workspace
    belongs_to :owner, class_name: "User", optional: true

    has_many :notes, as: :notable, dependent: :destroy
    has_many :comments, as: :commentable, dependent: :destroy
    has_many :tasks, as: :taskable, dependent: :destroy
    has_many :list_entries, as: :record, dependent: :destroy
    has_many :lists, through: :list_entries
    has_many :record_attachments, as: :attachable, dependent: :destroy
    has_many :email_messages, as: :record, dependent: :destroy

    after_create_commit :dispatch_created_webhook
    after_update_commit :dispatch_updated_webhook
  end

  class_methods do
    def record_type_label
      model_name.human
    end
  end

  def formula_fields_hash
    custom_field_definitions.where(field_type: "formula").each_with_object({}) do |field, hash|
      hash[field.key] = FormulaEvaluator.evaluate(field.formula_expression, record: self)
    end
  end

  private

  def dispatch_created_webhook
    return unless CreamFeatures.enabled?(:webhooks)

    WebhookDispatcher.dispatch(
      workspace: workspace,
      event: "record.created",
      payload: webhook_payload
    )
    run_automations("record.created")
  end

  def dispatch_updated_webhook
    return unless CreamFeatures.enabled?(:webhooks)

    WebhookDispatcher.dispatch(
      workspace: workspace,
      event: "record.updated",
      payload: webhook_payload
    )
  end

  def run_automations(event, metadata: {})
    return unless CreamFeatures.enabled?(:automations)

    AutomationJob.perform_later(event, self, metadata)
  end

  def webhook_payload
    {
      type: self.class.name.downcase,
      id: id,
      name: display_name,
      workspace_id: workspace_id
    }
  end
end
