# Offers become a named container; the PDF/HTML content lives in numbered versions.
# Existing offers keep their content as version 1.
class CreateOfferVersions < ActiveRecord::Migration[8.1]
  def up
    create_table :offer_versions do |t|
      t.references :offer, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :number, null: false
      t.text :html_body
      t.text :comment

      t.timestamps
    end
    add_index :offer_versions, %i[offer_id number], unique: true

    execute <<~SQL.squish
      INSERT INTO offer_versions (offer_id, user_id, number, html_body, created_at, updated_at)
      SELECT id, user_id, 1, html_body, created_at, updated_at FROM offers
    SQL
    execute <<~SQL.squish
      UPDATE active_storage_attachments
      SET record_type = 'OfferVersion', record_id = offer_versions.id
      FROM offer_versions
      WHERE active_storage_attachments.record_type = 'Offer'
        AND active_storage_attachments.name = 'file'
        AND active_storage_attachments.record_id = offer_versions.offer_id
    SQL

    remove_column :offers, :html_body
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
