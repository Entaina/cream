# Entry rule for a pipeline stage: all active conditions must pass before a deal
# can move into the stage. Fields may belong to the deal, its company, or any contact.
class StageCondition < ApplicationRecord
  include FieldCondition

  belongs_to :workspace
  belongs_to :pipeline_stage
  has_one :pipeline, through: :pipeline_stage

  validate :stage_belongs_to_workspace

  private

  def stage_belongs_to_workspace
    return if pipeline_stage.nil? || pipeline_stage.workspace_id == workspace_id

    errors.add(:pipeline_stage, :must_belong_to_same_workspace)
  end
end
