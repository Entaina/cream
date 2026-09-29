class AddGaMeasurementIdToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :ga_measurement_id, :string
  end
end
