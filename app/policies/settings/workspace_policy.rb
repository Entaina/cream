module Settings
  class WorkspacePolicy < ApplicationPolicy
    def show? = admin?
    def update? = admin?
  end
end
