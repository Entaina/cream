class StageTrigger < ApplicationRecord
  EXECUTION_MODES = %w[llm native].freeze

  belongs_to :workspace
  belongs_to :pipeline_stage
  has_one :pipeline, through: :pipeline_stage
  has_many :runs, class_name: "StageTriggerRun", dependent: :destroy

  validates :name, presence: true
  validates :execution_mode, inclusion: {in: EXECUTION_MODES}
  validates :instructions, presence: true, if: :llm?
  validates :native_function, presence: true,
    inclusion: {in: ->(_) { StageTriggers::NativeRegistry.keys }}, if: :native?
  validate :stage_belongs_to_workspace
  validate :required_native_params_present, if: :native?

  before_validation :prune_native_params

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :id) }

  def llm? = execution_mode == "llm"
  def native? = execution_mode == "native"

  def registry_entry
    return nil unless native? && StageTriggers::NativeRegistry.key?(native_function)

    StageTriggers::NativeRegistry.fetch(native_function)
  end

  private

  def stage_belongs_to_workspace
    return if pipeline_stage.nil? || pipeline_stage.workspace_id == workspace_id

    errors.add(:pipeline_stage, "must belong to the same workspace")
  end

  # Keep only the params declared by the selected function (the form submits
  # one fieldset per function; hidden ones are disabled client-side, but the
  # model must not trust that).
  def prune_native_params
    entry = registry_entry
    self.native_params = entry ? native_params.to_h.slice(*entry.params.map(&:key)) : {}
  end

  def required_native_params_present
    registry_entry&.params&.select(&:required)&.each do |param|
      if native_params[param.key].blank?
        errors.add(:native_params, I18n.t("stage_triggers.errors.param_required", label: param.label))
      end
    end
  end
end
