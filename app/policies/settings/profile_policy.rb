module Settings
  class ProfilePolicy < ApplicationPolicy
    def show? = member?
    def update? = member?
  end
end
