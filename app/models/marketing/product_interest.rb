module Marketing
  class ProductInterest < ApplicationRecord
    self.table_name = "marketing_product_interests"

    STATUSES = %w[pending converted dismissed].freeze
    SOURCE_KINDS = %w[manual lead_form].freeze

    belongs_to :workspace
    belongs_to :person
    belongs_to :product
    belongs_to :recorded_by, class_name: "User", optional: true
    belongs_to :deal, optional: true
    belongs_to :converted_by, class_name: "User", optional: true
    belongs_to :lead_submission, optional: true

    validates :status, inclusion: {in: STATUSES}
    validates :source_kind, inclusion: {in: SOURCE_KINDS}
    validates :description, presence: true
    validates :occurred_at, presence: true
    validates :dismissal_reason, presence: true, if: -> { status == "dismissed" }
    validates :lead_submission_id, uniqueness: {scope: :product_id}, allow_nil: true
    validate :references_belong_to_workspace
    validate :converted_fields_consistent

    scope :pending, -> { where(status: "pending") }
    scope :ordered, -> { order(occurred_at: :desc, id: :desc) }

    def pending?
      status == "pending"
    end

    def converted?
      status == "converted"
    end

    def dismiss!(reason:, actor:)
      update!(
        status: "dismissed",
        dismissal_reason: reason,
        recorded_by: actor
      )
    end

    private

    def references_belong_to_workspace
      return if workspace.nil?

      errors.add(:person, "must belong to the workspace") if person && person.workspace_id != workspace_id
      errors.add(:product, "must belong to the workspace") if product && product.workspace_id != workspace_id
      if lead_submission && lead_submission.workspace_id != workspace_id
        errors.add(:lead_submission, "must belong to the workspace")
      end
    end

    def converted_fields_consistent
      return unless converted?

      errors.add(:deal, "is required when converted") if deal_id.blank?
      errors.add(:converted_at, "is required when converted") if converted_at.blank?
    end
  end
end
