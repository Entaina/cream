class EmailVerificationsMailer < ApplicationMailer
  def verify(user)
    @user = user

    with_mailer_locale(user.locale) do
      @expires_distance = distance_of_time_in_words(0, User::EMAIL_VERIFICATION_EXPIRES_IN)
      mail subject: t("email_verifications_mailer.verify.subject"), to: user.email_address
    end
  end

  private

  def mailjet_workspace = @user.default_workspace
end
