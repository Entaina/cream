class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end

  private

  def mailjet_workspace = @user.default_workspace
end
