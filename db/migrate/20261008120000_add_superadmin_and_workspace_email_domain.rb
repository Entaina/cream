class AddSuperadminAndWorkspaceEmailDomain < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :superadmin, :boolean, null: false, default: false
    add_column :workspaces, :email_domain, :string
    add_column :memberships, :superadmin_access, :boolean, null: false, default: false

    add_index :workspaces, :email_domain, unique: true, where: "email_domain IS NOT NULL"

    migrate_organization_email_domain_from_env
  end

  def down
    remove_index :workspaces, :email_domain
    remove_column :memberships, :superadmin_access
    remove_column :workspaces, :email_domain
    remove_column :users, :superadmin
  end

  private

  def migrate_organization_email_domain_from_env
    domain = ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"].to_s.strip.downcase.delete_prefix("@")
    return if domain.blank?

    workspace_name = ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"].presence
    return if workspace_name.blank?

    slug = workspace_name.parameterize
    execute(ActiveRecord::Base.sanitize_sql_array([
      "UPDATE workspaces SET email_domain = ? WHERE slug = ? AND email_domain IS NULL",
      domain,
      slug
    ]))
  end
end
