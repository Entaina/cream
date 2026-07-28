class AddCardFieldsToPipelines < ActiveRecord::Migration[8.0]
  def change
    add_column :pipelines, :card_fields, :string, array: true, null: false,
      default: %w[value company expected_close_date owner]
  end
end
