class MarketingGapClosure < ActiveRecord::Migration[8.1]
  def change
    add_column :lead_form_templates, :kind, :string, null: false, default: "form"
    add_index :lead_form_templates, :kind

    create_table :segment_memberships do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :segment, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.datetime :entered_at, null: false
      t.timestamps
    end
    add_index :segment_memberships, [:segment_id, :person_id], unique: true
  end
end
