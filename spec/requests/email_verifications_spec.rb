require "rails_helper"

RSpec.describe "Email verifications", type: :request do
  describe "POST /email_verifications" do
    it "enqueues a link for an unconfirmed account" do
      user = User.create!(name: "Pending", email_address: "pending@example.com", password: "password")

      expect {
        post email_verifications_path, params: {email_address: user.email_address}
      }.to have_enqueued_mail(EmailVerificationsMailer, :verify).with(user)

      expect(response).to redirect_to(new_session_path)
    end

    it "does not send mail for an unknown address" do
      expect {
        post email_verifications_path, params: {email_address: "missing@example.com"}
      }.not_to have_enqueued_mail(EmailVerificationsMailer, :verify)

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /email_verifications/:token" do
    it "rejects a token that was already used" do
      user = User.create!(name: "Pending", email_address: "pending@example.com", password: "password")
      token = user.email_verification_token
      user.confirm_email_and_provision!

      get email_verification_path(token)

      expect(response).to redirect_to(new_email_verification_path)
    end
  end
end
