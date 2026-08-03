class AddSuccessRedirectUrlToLeadForms < ActiveRecord::Migration[8.0]
  def change
    add_column :lead_forms, :success_redirect_url, :string
  end
end
