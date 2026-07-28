class RelationalConstraints < ActiveRecord::Migration[8.1]
  def up
    create_table :deal_contacts do |t|
      t.references :deal, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.timestamps
    end
    add_index :deal_contacts, [ :deal_id, :person_id ], unique: true

    # Backfill the join from the old single primary contact.
    execute(<<~SQL)
      INSERT INTO deal_contacts (deal_id, person_id, created_at, updated_at)
      SELECT id, person_id, NOW(), NOW() FROM deals WHERE person_id IS NOT NULL
    SQL

    remove_reference :deals, :person, foreign_key: true

    # A person now belongs to a company, and a deal belongs to a company (both required).
    change_column_null :people, :company_id, false
    change_column_null :deals, :company_id, false
  end

  def down
    change_column_null :deals, :company_id, true
    change_column_null :people, :company_id, true

    add_reference :deals, :person, foreign_key: true
    execute(<<~SQL)
      UPDATE deals d SET person_id = dc.person_id
      FROM deal_contacts dc
      WHERE dc.deal_id = d.id
        AND dc.id = (SELECT MIN(id) FROM deal_contacts WHERE deal_id = d.id)
    SQL

    drop_table :deal_contacts
  end
end
