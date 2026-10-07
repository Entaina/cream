class CreateOffers < ActiveRecord::Migration[8.1]
  def change
    create_table :offers do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :deal, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :html_body

      t.timestamps
    end
  end
end
