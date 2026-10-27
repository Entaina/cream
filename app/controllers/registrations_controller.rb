class RegistrationsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_registration_path, alert: I18n.t("auth.flashes.try_again_later")
  }

  def new
    unless User.public_signup_enabled?
      redirect_to new_session_path, alert: t("auth.sign_up_disabled")
      return
    end

    @user = User.new
  end

  def create
    @user = User.new(user_params)
    apply_guest_locale(@user)

    unless User.allowed_to_register?(@user.email_address)
      redirect_to new_session_path, alert: t("auth.sign_up_disabled")
      return
    end

    existing = User.find_by(email_address: @user.email_address)
    if existing && !existing.email_verified?
      existing.assign_attributes(user_params)
      apply_guest_locale(existing)
      @user = existing
    end

    @user.pending_workspace_name = params[:workspace_name].presence

    if @user.save
      persist_locale_cookie(@user.locale)
      EmailVerificationsMailer.verify(@user).deliver_later
      redirect_to new_session_path, notice: t("auth.flashes.email_verification_sent")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end

  def apply_guest_locale(user)
    guest_locale = cookies[:locale].presence_in(User::LOCALES)
    user.locale = guest_locale if guest_locale
  end
end
