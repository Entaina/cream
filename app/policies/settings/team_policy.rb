module Settings
  class TeamPolicy < ApplicationPolicy
    def show? = member?
    def update? = admin?
  end
end
