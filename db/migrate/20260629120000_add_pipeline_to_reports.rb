class AddPipelineToReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :reports, :pipeline, null: true, foreign_key: true
  end
end
