module Superadmin
  class BaseController < ApplicationController
    skip_after_action :verify_authorized, only: :index
    skip_after_action :verify_policy_scoped, only: :index
    after_action :verify_authorized, except: :index
    after_action :verify_policy_scoped, only: :index

    before_action :require_superadmin!

    rescue_from ActiveRecord::RecordNotFound, with: :not_found

    private

    def require_superadmin!
      not_found unless current_user&.superadmin?
    end

    def not_found
      raise ActionController::RoutingError, "Not Found"
    end

    def pundit_user
      current_user
    end

    def authorize(record, query = nil, policy_class: nil, **options)
      super(record, query, policy_class: policy_class || superadmin_policy_class(record), **options)
    end

    def policy_scope(scope, policy_scope_class: nil)
      super(scope, policy_scope_class: policy_scope_class || superadmin_scope_class(scope))
    end

    def superadmin_policy_class(record)
      model = record.is_a?(Class) ? record : record.class
      case model.name
      when "Workspace" then Superadmin::WorkspacePolicy
      when "Membership" then Superadmin::MembershipPolicy
      else Superadmin::ApplicationPolicy
      end
    end

    def superadmin_scope_class(scope)
      model = scope.respond_to?(:model) ? scope.model : scope
      case model.name
      when "Workspace" then Superadmin::WorkspacePolicy::Scope
      when "Membership" then Superadmin::MembershipPolicy::Scope
      else Superadmin::ApplicationPolicy::Scope
      end
    end
  end
end
