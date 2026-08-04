class AddPipelineStageToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_reference :lead_forms, :pipeline_stage, null: true, foreign_key: true
  end
end
