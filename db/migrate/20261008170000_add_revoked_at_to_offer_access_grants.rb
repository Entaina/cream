class AddRevokedAtToOfferAccessGrants < ActiveRecord::Migration[8.1]
  def change
    add_column :offer_access_grants, :revoked_at, :datetime
  end
end
