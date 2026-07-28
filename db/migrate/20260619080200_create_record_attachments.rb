class CreateRecordAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :record_attachments do |t|
      t.references :workspace, null: false, foreign_key: true
      t.references :attachable, null: false, polymorphic: true
      t.references :user, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
