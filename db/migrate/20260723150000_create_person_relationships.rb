class CreatePersonRelationships < ActiveRecord::Migration[8.0]
  def change
    create_table :person_relationships do |t|
      t.references :from_person, null: false, foreign_key: {to_table: :people}
      t.references :to_person, null: false, foreign_key: {to_table: :people}
      t.string :relationship_type, null: false

      t.timestamps
    end

    add_index :person_relationships, [:from_person_id, :to_person_id, :relationship_type],
      unique: true, name: "index_person_relationships_on_from_to_type"
  end
end
