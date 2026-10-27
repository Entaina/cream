class InvitationAcceptsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped
  skip_before_action :ensure_workspace_membership

  allow_unauthenticated_access only: %i[show create]

  before_action :resume_session, only: %i[show create]
  before_action :set_invitation

  def show
    store_pending_invitation_token

    if @invitation.accepted?
      render :accepted
    elsif @invitation.expired?
      render :expired
    elsif current_user&.email_address == @invitation.email_address
      @ready_to_accept = true
    elsif current_user
      @email_mismatch = true
    elsif (existing = User.find_by(email_address: @invitation.email_address))&.email_verified?
      @existing_user = true
    else
      @user = existing || User.new(email_address: @invitation.email_address)
    end
  end

  def create
    store_pending_invitation_token

    if current_user
      accept_for_current_user
    else
      accept_with_registration
    end
  end

  private

  def set_invitation
    @invitation = Invitation.find_by_token(params[:token])
    return if @invitation

    redirect_to new_session_path, alert: t("auth.flashes.invitation_invalid") and return
  end

  def store_pending_invitation_token
    session[:pending_invitation_token] = params[:token] if @invitation&.pending?
  end

  def accept_for_current_user
    unless current_user.email_address == @invitation.email_address
      redirect_to accept_invitation_path(params[:token]), alert: t("auth.flashes.sign_in_with_invited_email", email: @invitation.email_address)
      return
    end

    @invitation.accept_for!(current_user)
    session.delete(:pending_invitation_token)
    session[:workspace_id] = @invitation.workspace_id
    redirect_to root_path, notice: t("auth.flashes.joined_workspace", workspace: @invitation.workspace.name)
  rescue ActiveRecord::RecordInvalid
    redirect_to accept_invitation_path(params[:token]), alert: @invitation.errors.full_messages.to_sentence.presence || t("auth.flashes.invitation_accept_failed")
  end

  def accept_with_registration
    existing = User.find_by(email_address: @invitation.email_address)
    if existing&.email_verified?
      redirect_to accept_invitation_path(params[:token]), alert: t("auth.flashes.sign_in_with_invited_email", email: @invitation.email_address)
      return
    end

    @user = existing || User.new
    @user.assign_attributes(user_params.merge(email_address: @invitation.email_address, email_verified_at: Time.current))
    @user.pending_workspace_name = nil

    if @user.save
      @invitation.accept_for!(@user)
      session.delete(:pending_invitation_token)
      start_new_session_for(@user)
      session[:workspace_id] = @invitation.workspace_id
      redirect_to root_path, notice: t("auth.flashes.welcome_workspace", workspace: @invitation.workspace.name)
    else
      render :show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid
    @user ||= User.new
    render :show, status: :unprocessable_entity
  end

  def user_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
