module Settings
  class ConnectedAppPolicy < ApplicationPolicy
    def show? = member?
    def destroy? = member?
  end
end
