class RegistrationsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  allow_unauthenticated_access only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    guest_locale = cookies[:locale].presence_in(User::LOCALES)
    @user.locale = guest_locale if guest_locale

    if @user.save
      persist_locale_cookie(@user.locale)
      User.provision_default_workspace!(@user, workspace_name: params[:workspace_name])
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome to Cream!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end
