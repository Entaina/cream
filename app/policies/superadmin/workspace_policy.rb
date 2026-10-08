module Superadmin
  class WorkspacePolicy < ApplicationPolicy
    class Scope < Scope
      def resolve
        super.order(:name)
      end
    end
  end
end
