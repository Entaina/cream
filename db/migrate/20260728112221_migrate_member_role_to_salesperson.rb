class MigrateMemberRoleToSalesperson < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE memberships SET role = 'salesperson' WHERE role = 'member'
    SQL
    execute <<~SQL.squish
      UPDATE invitations SET role = 'salesperson' WHERE role = 'member'
    SQL
    change_column_default :memberships, :role, from: "member", to: "salesperson"
    change_column_default :invitations, :role, from: "member", to: "salesperson"
  end

  def down
    execute <<~SQL.squish
      UPDATE memberships SET role = 'member' WHERE role = 'salesperson'
    SQL
    execute <<~SQL.squish
      UPDATE invitations SET role = 'member' WHERE role = 'salesperson'
    SQL
    change_column_default :memberships, :role, from: "salesperson", to: "member"
    change_column_default :invitations, :role, from: "salesperson", to: "member"
  end
end
