class AddExecutionAndPaymentFieldsToDeals < ActiveRecord::Migration[8.0]
  def change
    change_table :deals, bulk: true do |t|
      t.date :execution_starts_on
      t.date :execution_ends_on
      t.string :payment_method
      t.date :payment_on
    end
  end
end
