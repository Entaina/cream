module Settings
  class TeamController < ApplicationController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    after_action :verify_authorized, only: :show

    helper_method :index_query_params

    def show
      authorize [:settings, :team]

      @admin = pundit_user.admin?
      memberships = policy_scope(Membership)
        .includes(:user)
        .joins(:user)
        .search(params[:q])
        .order("users.name")
      @pagy, @memberships = pagy(:offset, memberships)
      @pending_invitations = if @admin
        policy_scope(Invitation).pending.order(created_at: :desc)
      else
        Invitation.none
      end
    end

    private

    def index_query_params(overrides = {})
      {q: params[:q]}.merge(overrides).compact_blank
    end
  end
end
