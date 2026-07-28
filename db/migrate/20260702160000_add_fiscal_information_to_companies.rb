class AddFiscalInformationToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :fiscal_information, :text
  end
end
