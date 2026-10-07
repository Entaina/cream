class MqlPolicy < ApplicationPolicy
  def index? = member?

  def create? = member?
end
