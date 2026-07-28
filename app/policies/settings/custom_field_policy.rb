module Settings
  class CustomFieldPolicy < ApplicationPolicy
    def index? = member?
    def new? = admin?
    def create? = admin?
    def edit? = admin?
    def update? = admin?
    def destroy? = admin?

    class Scope < Scope
      def resolve
        return scope.none unless member?

        scope.where(workspace: workspace)
      end
    end
  end
end
