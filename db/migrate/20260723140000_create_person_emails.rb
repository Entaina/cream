class CreatePersonEmails < ActiveRecord::Migration[8.0]
  def up
    create_table :person_emails do |t|
      t.references :person, null: false, foreign_key: true
      t.references :workspace, null: false, foreign_key: true
      t.string :address, null: false
      t.boolean :primary, null: false, default: false
      t.timestamps
    end

    add_index :person_emails, [ :workspace_id, :address ]
    add_index :person_emails, [ :person_id, :primary ]

    execute <<~SQL.squish
      INSERT INTO person_emails (person_id, workspace_id, address, "primary", created_at, updated_at)
      SELECT id, workspace_id, LOWER(TRIM(email)), true, created_at, updated_at
      FROM people
      WHERE email IS NOT NULL AND TRIM(email) <> ''
    SQL
  end

  def down
    drop_table :person_emails
  end
end
