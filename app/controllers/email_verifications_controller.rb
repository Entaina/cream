class EmailVerificationsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> {
    redirect_to new_email_verification_path, alert: I18n.t("auth.flashes.try_again_later")
  }

  def new
  end

  def create
    email = params[:email_address].to_s.strip.downcase
    if (user = User.find_by(email_address: email)) && !user.email_verified?
      EmailVerificationsMailer.verify(user).deliver_later
    end

    redirect_to new_session_path, notice: t("auth.flashes.email_verification_sent")
  end

  def show
    user = User.find_by_token_for!(:email_verification, params[:token])
    user.confirm_email_and_provision!
    if user.workspaces.none?
      redirect_to new_session_path, alert: t("auth.sign_up_disabled")
      return
    end

    start_new_session_for user
    redirect_to root_path, notice: t("flashes.registrations.welcome")
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_email_verification_path, alert: t("auth.flashes.email_verification_invalid")
  end
end
