require "rails_helper"

RSpec.describe "Sessions", type: :request do
  # memberships too: DELETE /session runs ensure_workspace_membership before destroy
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }

  describe "GET /session/new" do
    it "renders the form" do
      get new_session_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /session" do
    it "signs in with valid credentials" do
      post session_path, params: {email_address: user.email_address, password: "password"}

      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end

    it "restores the user's preferred pipeline after login" do
      workspace = workspaces(:one)
      pipeline = Pipeline.create_default!(workspace)
      preferred_pipeline = pipeline.duplicate(name: "Partners").tap(&:save!)
      memberships(:one_one).update!(current_pipeline: preferred_pipeline)

      post session_path, params: {email_address: user.email_address, password: "password"}
      follow_redirect!

      selected_option = Nokogiri::HTML(response.body).at_css("select[name='pipeline_id'] option[selected]")
      expect(selected_option["value"]).to eq(preferred_pipeline.id.to_s)
    end

    it "rejects a correct password until the email is confirmed" do
      pending = User.create!(name: "Pending", email_address: "pending@example.com", password: "password")

      expect {
        post session_path, params: {email_address: pending.email_address, password: "password"}
      }.to have_enqueued_mail(EmailVerificationsMailer, :verify)

      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_blank
      follow_redirect!
      expect_notice(I18n.t("auth.flashes.email_unverified"))
    end

    it "rejects invalid credentials" do
      post session_path, params: {email_address: user.email_address, password: "wrong"}

      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_nil
    end
  end

  describe "DELETE /session" do
    it "signs out" do
      sign_in_as(user)

      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_blank
    end
  end
end
