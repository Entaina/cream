class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user

    with_mailer_locale(user.locale) do
      @expires_distance = distance_of_time_in_words(0, user.password_reset_token_expires_in)
      mail subject: t("passwords_mailer.reset.subject"), to: user.email_address
    end
  end

  private

  def mailjet_workspace = @user.default_workspace
end
