# Workspace configuration that every member can use but only admins and sales
# directors can change.
module SettingsManagedPolicy
  def create? = settings_manager? && super
  def update? = settings_manager? && super
  def destroy? = settings_manager? && super

  private

  def settings_manager? = admin? || context.sales_director?
end
