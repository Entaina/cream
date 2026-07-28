class AddPipelineRoutesToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :pipeline_routes, :jsonb, null: false, default: {}
  end
end
