module Settings
  class TeamController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: :show

    def show
      authorize [ :settings, :team ]

      @memberships = policy_scope(Membership).order(:created_at)
      @pending_invitations = policy_scope(Invitation).pending.order(created_at: :desc)
      @admin = pundit_user.admin?
    end
  end
end
