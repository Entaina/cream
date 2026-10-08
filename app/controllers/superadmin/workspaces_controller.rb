module Superadmin
  class WorkspacesController < BaseController
    before_action :set_workspace, only: %i[show edit update enter]

    def index
      @workspaces = policy_scope(Workspace).includes(:memberships)
    end

    def show
      authorize @workspace
      @memberships = policy_scope(Membership).where(workspace: @workspace)
      @pending_invitations = @workspace.invitations.pending.order(created_at: :desc)
    end

    def new
      @workspace = Workspace.new
      authorize @workspace
    end

    def create
      @workspace = Workspace.new(create_workspace_params)
      authorize @workspace

      ActiveRecord::Base.transaction do
        @workspace.save!
        assign_initial_admin!(@workspace)
      end

      redirect_to superadmin_workspace_path(@workspace), notice: t("flashes.superadmin.workspace_created")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit
      authorize @workspace
    end

    def update
      authorize @workspace

      if @workspace.update(update_workspace_params)
        redirect_to superadmin_workspace_path(@workspace), notice: t("flashes.superadmin.workspace_updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def enter
      authorize @workspace, :enter?

      current_user.ensure_superadmin_support_membership!(@workspace)
      session[:workspace_id] = @workspace.id
      redirect_to root_path, notice: t("flashes.superadmin.entered_workspace", name: @workspace.name)
    end

    private

    def set_workspace
      @workspace = policy_scope(Workspace).find(params[:id])
    end

    def create_workspace_params
      params.require(:workspace).permit(:name, :slug, :email_domain, :time_zone)
    end

    def update_workspace_params
      params.require(:workspace).permit(
        :name,
        :email_domain,
        :time_zone,
        :sales_director_enabled,
        :salespeople_can_view_all_deals,
        :salespeople_can_edit_all_deals,
        :okm_chat_enabled,
        :reports_enabled,
        :marketing_attribution_enabled,
        :lead_scoring_enabled,
        :webhooks_enabled,
        :custom_fields_enabled
      )
    end

    def assign_initial_admin!(workspace)
      email = params.dig(:workspace, :initial_admin_email).to_s.strip.downcase
      role = params.dig(:workspace, :initial_admin_role).presence || "admin"
      role = "admin" unless Membership::ROLES.include?(role)
      return if email.blank?

      user = User.find_by(email_address: email)
      if user
        membership = workspace.memberships.find_or_initialize_by(user: user)
        membership.role = role
        membership.superadmin_access = false
        membership.save!
      else
        invitation = workspace.invitations.create!(
          email_address: email,
          role: role,
          invited_by: current_user
        )
        InvitationMailer.invite(invitation, invitation.plaintext_token).deliver_later
      end
    end
  end
end
