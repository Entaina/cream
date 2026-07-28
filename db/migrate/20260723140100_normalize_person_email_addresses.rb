class NormalizePersonEmailAddresses < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      UPDATE person_emails SET address = LOWER(TRIM(address))
      WHERE address <> LOWER(TRIM(address))
    SQL
  end

  def down
  end
end
