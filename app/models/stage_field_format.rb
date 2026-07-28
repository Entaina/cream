# Per-stage display rule for a deal field: when the condition matches, the
# views show display_text instead of the formatted value (e.g. price 0 in a
# given stage renders as "guest"). First matching active rule wins.
class StageFieldFormat < ApplicationRecord
  FIELDS = {
    "value" => "Precio",
    "probability" => "Probabilidad",
    "expected_close_date" => "Fecha de cierre"
  }.freeze
  OPERATORS = {
    "eq" => "es igual a",
    "lt" => "es menor que",
    "gt" => "es mayor que",
    "blank" => "está vacío"
  }.freeze

  belongs_to :workspace
  belongs_to :pipeline_stage
  has_one :pipeline, through: :pipeline_stage

  validates :field, inclusion: { in: FIELDS.keys }
  validates :operator, inclusion: { in: OPERATORS.keys }
  validates :display_text, presence: true
  validates :compare_value, presence: true, unless: :blank_operator?
  validate :stage_belongs_to_workspace

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def self.display_for(deal, field)
    deal.pipeline_stage.stage_field_formats.active.ordered
      .detect { |format| format.field == field.to_s && format.matches?(deal) }
      &.display_text
  end

  def matches?(deal)
    raw = deal.public_send(field)
    case operator
    when "blank" then raw.blank?
    when "eq" then compare(raw) == 0
    when "lt" then compare(raw)&.negative?
    when "gt" then compare(raw)&.positive?
    end
  end

  def blank_operator? = operator == "blank"

  private

  # <=> of the deal's raw value against compare_value, nil when not comparable.
  def compare(raw)
    return nil if raw.nil? || compare_value.nil?

    if field == "expected_close_date"
      raw.to_date <=> Date.parse(compare_value)
    else
      raw.to_d <=> compare_value.to_d
    end
  rescue ArgumentError
    nil
  end

  def stage_belongs_to_workspace
    return if pipeline_stage.nil? || pipeline_stage.workspace_id == workspace_id

    errors.add(:pipeline_stage, "must belong to the same workspace")
  end
end
