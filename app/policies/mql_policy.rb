class MqlPolicy < ApplicationPolicy
  def index? = member?
end
