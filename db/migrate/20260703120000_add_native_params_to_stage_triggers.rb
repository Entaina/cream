class AddNativeParamsToStageTriggers < ActiveRecord::Migration[8.0]
  def change
    add_column :stage_triggers, :native_params, :jsonb, null: false, default: {}
  end
end
