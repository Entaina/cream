module Superadmin
  class MembershipPolicy < ApplicationPolicy
    def destroy?
      superadmin? && !record.superadmin_access?
    end

    class Scope < Scope
      def resolve
        return scope.none unless user&.superadmin?

        scope.real_team.joins(:user).includes(:user).order("users.name")
      end
    end
  end
end
