require "rails_helper"

RSpec.describe "Passwords", type: :request do
  fixtures :users

  let(:user) { users(:one) }

  describe "GET /passwords/new" do
    it "renders the form" do
      get new_password_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /passwords" do
    it "enqueues reset mail and redirects" do
      expect {
        post passwords_path, params: {email_address: user.email_address}
      }.to have_enqueued_mail(PasswordsMailer, :reset).with(user)

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect_notice(I18n.t("auth.flashes.password_reset_sent"))
    end

    it "redirects for unknown user without sending mail" do
      expect {
        post passwords_path, params: {email_address: "missing-user@example.com"}
      }.not_to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to(new_session_path)
      follow_redirect!
      expect_notice(I18n.t("auth.flashes.password_reset_sent"))
    end
  end

  describe "GET /passwords/:token/edit" do
    it "renders the form" do
      get edit_password_path(user.password_reset_token)
      expect(response).to have_http_status(:success)
    end

    it "redirects with invalid password reset token" do
      get edit_password_path("invalid token")

      expect(response).to redirect_to(new_password_path)
      follow_redirect!
      expect_notice(I18n.t("auth.flashes.password_reset_invalid"))
    end
  end

  describe "PUT /passwords/:token" do
    it "updates the password" do
      expect {
        put password_path(user.password_reset_token), params: {password: "new", password_confirmation: "new"}
        expect(response).to redirect_to(new_session_path)
      }.to change { user.reload.password_digest }

      follow_redirect!
      expect_notice(I18n.t("auth.flashes.password_reset"))
    end

    it "confirms the email when an unconfirmed account resets the password" do
      pending = User.create!(name: "Pending", email_address: "pending-reset@example.com", password: "password")

      put password_path(pending.password_reset_token), params: {password: "newpassword", password_confirmation: "newpassword"}

      expect(response).to redirect_to(new_session_path)
      expect(pending.reload.email_verified?).to be true
      expect(pending.authenticate("newpassword")).to eq(pending)
    end

    it "rejects non matching passwords" do
      token = user.password_reset_token

      expect {
        put password_path(token), params: {password: "no", password_confirmation: "match"}
        expect(response).to redirect_to(edit_password_path(token))
      }.not_to change { user.reload.password_digest }

      follow_redirect!
      expect_notice(I18n.t("auth.flashes.passwords_did_not_match"))
    end
  end
end
