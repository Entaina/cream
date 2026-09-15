class AddCurrentPipelineToMemberships < ActiveRecord::Migration[8.1]
  def up
    add_reference :memberships, :current_pipeline, null: true,
      foreign_key: {to_table: :pipelines, on_delete: :nullify}

    say_with_time "Backfill membership current pipelines" do
      Membership.reset_column_information
      Membership.find_each do |membership|
        default = Pipeline.default_for(membership.workspace)
        membership.update_column(:current_pipeline_id, default.id) if default
      end
    end
  end

  def down
    remove_reference :memberships, :current_pipeline,
      foreign_key: {to_table: :pipelines}
  end
end
