class CreateSavedViews < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_views do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :record_type, null: false
      t.string :name, null: false
      t.jsonb :filters, null: false, default: {}
      t.string :sort
      t.string :direction, null: false, default: "asc"
      t.boolean :shared, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :saved_views, %i[workspace_id record_type]
  end
end
