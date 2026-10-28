class PasswordsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[edit update]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: I18n.t("auth.flashes.try_again_later") }

  def new
  end

  def create
    if (user = User.find_by(email_address: params[:email_address]))
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: t("auth.flashes.password_reset_sent")
  end

  def edit
  end

  def update
    was_unverified = !@user.email_verified?
    if @user.update(params.permit(:password, :password_confirmation))
      @user.confirm_email_and_provision! if was_unverified
      @user.sessions.destroy_all
      revoke_oauth_tokens_for!(@user)
      redirect_to new_session_path, notice: t("auth.flashes.password_reset")
    else
      alert = if @user.errors.of_kind?(:password_confirmation, :confirmation)
        t("auth.flashes.passwords_did_not_match")
      else
        @user.errors.full_messages.to_sentence
      end
      redirect_to edit_password_path(params[:token]), alert: alert
    end
  end

  private

  def revoke_oauth_tokens_for!(user)
    Doorkeeper::AccessToken.where(resource_owner_id: user.id, revoked_at: nil)
      .update_all(revoked_at: Time.current)
  end

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: t("auth.flashes.password_reset_invalid")
  end
end
