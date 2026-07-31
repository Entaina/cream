class AddProductToEditions < ActiveRecord::Migration[8.1]
  class MigrationEdition < ApplicationRecord
    self.table_name = "editions"
  end

  class MigrationDealProduct < ApplicationRecord
    self.table_name = "deal_products"
  end

  def up
    add_reference :editions, :product, foreign_key: true, null: true

    # Drop workspace-scoped uniqueness before duplicating editions per product;
    # the new model scopes name uniqueness to product_id instead.
    remove_index :editions, name: "index_editions_on_workspace_id_and_name"

    say_with_time "Assign editions to products based on deal line usage" do
      migrate_editions_to_products
    end
    MigrationEdition.where(product_id: nil).delete_all
    change_column_null :editions, :product_id, false
    add_index :editions, [ :product_id, :name ], unique: true
  end

  def down
    remove_index :editions, name: "index_editions_on_product_id_and_name"
    change_column_null :editions, :product_id, true
    add_index :editions, [ :workspace_id, :name ], unique: true
    remove_reference :editions, :product, foreign_key: true
  end

  private

  def migrate_editions_to_products
    pairs = MigrationDealProduct.where.not(edition_id: nil).distinct.pluck(:edition_id, :product_id)
    pairs.group_by(&:first).each do |edition_id, edition_pairs|
      edition = MigrationEdition.find(edition_id)
      product_ids = edition_pairs.map(&:last).uniq

      edition.update_column(:product_id, product_ids.first)

      product_ids[1..].each do |product_id|
        copy = edition.dup
        copy.product_id = product_id
        copy.save!(validate: false)

        MigrationDealProduct.where(edition_id: edition_id, product_id: product_id)
          .update_all(edition_id: copy.id)
      end
    end
  end
end
