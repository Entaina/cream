class AddInvoiceNumberToDeals < ActiveRecord::Migration[8.0]
  def change
    add_column :deals, :invoice_number, :string
    add_index :deals, %i[workspace_id invoice_number], name: "index_deals_on_workspace_id_and_invoice_number"
  end
end
