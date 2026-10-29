require "rails_helper"

RSpec.describe "OmniauthCallbacks", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }

  before do
    OmniAuth.config.test_mode = true
  end

  after do
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
  end

  def mock_google_auth(uid:, email:, name:, email_verified: true)
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: OmniAuth::AuthHash::InfoHash.new(email: email, name: name),
      extra: OmniAuth::AuthHash.new(raw_info: {"email_verified" => email_verified})
    )
  end

  describe "GET /auth/google_oauth2/callback" do
    it "signs in an existing user matched by provider and uid" do
      user.update!(provider: "google_oauth2", uid: "12345")
      mock_google_auth(uid: "12345", email: user.email_address, name: user.name)

      get "/auth/google_oauth2/callback"

      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end

    it "links Google to an existing user matched by email" do
      mock_google_auth(uid: "67890", email: user.email_address, name: user.name)

      expect {
        get "/auth/google_oauth2/callback"
      }.not_to change(User, :count)

      expect(user.reload.provider).to eq("google_oauth2")
      expect(user.uid).to eq("67890")
      expect(user.authenticate("password")).to eq(user)
      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end

    it "creates a user and workspace for a new Google account" do
      mock_google_auth(uid: "new-user", email: "new@example.com", name: "New User")

      expect {
        get "/auth/google_oauth2/callback"
      }.to change(User, :count).by(1)
        .and change(Workspace, :count).by(1)
        .and change(Membership, :count).by(1)

      new_user = User.find_by!(email_address: "new@example.com")
      expect(new_user.provider).to eq("google_oauth2")
      expect(new_user.uid).to eq("new-user")
      expect(new_user.email_verified?).to be true
      expect(new_user.workspaces.count).to eq(1)
      expect(new_user.memberships.first.role).to eq("admin")
      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end

    it "also joins the demo workspace for a new Google account when it exists" do
      demo = Workspace.create!(name: "Cream Demo", slug: "cream-demo")
      mock_google_auth(uid: "new-user", email: "new@example.com", name: "New User")

      expect {
        get "/auth/google_oauth2/callback"
      }.to change(User, :count).by(1)
        .and change(Workspace, :count).by(1)
        .and change(Membership, :count).by(2)

      new_user = User.find_by!(email_address: "new@example.com")
      personal_workspace = new_user.workspaces.find_by!(name: "New User's Workspace")
      expect(new_user.workspaces).to contain_exactly(demo, personal_workspace)
      expect(new_user.memberships.find_by!(workspace: demo).role).to eq("salesperson")
      expect(new_user.memberships.find_by!(workspace: personal_workspace).role).to eq("admin")
    end

    it "joins the organization workspace for new matching Google accounts" do
      original_domain = ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"]
      original_name = ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"]
      ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"] = "example.com"
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"] = "Example"

      org = Workspace.create!(name: "Example", slug: "example")
      org.memberships.create!(user: users(:two), role: "admin")

      mock_google_auth(uid: "org-user", email: "new.colleague@example.com", name: "New Colleague")

      demo = Workspace.create!(name: "Cream Demo", slug: "cream-demo")

      expect {
        get "/auth/google_oauth2/callback"
      }.to change(User, :count).by(1)
        .and change(Membership, :count).by(2)
        .and change(Workspace, :count).by(0)

      new_user = User.find_by!(email_address: "new.colleague@example.com")
      expect(new_user.workspaces).to contain_exactly(org, demo)
      expect(new_user.memberships.find_by!(workspace: org).role).to eq("salesperson")
      expect(new_user.memberships.find_by!(workspace: demo).role).to eq("salesperson")
    ensure
      ENV["CREAM_ORGANIZATION_EMAIL_DOMAIN"] = original_domain
      ENV["CREAM_ORGANIZATION_WORKSPACE_NAME"] = original_name
    end

    it "rejects a new Google account whose email is not verified" do
      mock_google_auth(uid: "unverified", email: "unverified@example.com", name: "Unverified", email_verified: false)

      expect {
        get "/auth/google_oauth2/callback"
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(I18n.t("auth.sign_up_disabled"))
      expect(cookies[:session_id]).to be_blank
    end

    it "does not link an unverified Google email to an existing user" do
      mock_google_auth(uid: "unverified-link", email: user.email_address, name: user.name, email_verified: false)

      get "/auth/google_oauth2/callback"

      expect(user.reload.uid).not_to eq("unverified-link")
      expect(response).to redirect_to(new_session_path)
      expect(cookies[:session_id]).to be_blank
    end

    it "still signs in a user already linked by provider and uid" do
      user.update!(provider: "google_oauth2", uid: "linked")
      mock_google_auth(uid: "linked", email: user.email_address, name: user.name, email_verified: false)

      get "/auth/google_oauth2/callback"

      expect(response).to redirect_to(root_path)
      expect(cookies[:session_id]).to be_present
    end
  end

  it "replaces the password when Google is linked to an unconfirmed account" do
    squatter = User.create!(
      name: "Squatter",
      email_address: "squatter@example.com",
      password: "attacker-password"
    )
    mock_google_auth(uid: "google-ana", email: squatter.email_address, name: "Ana")

    get "/auth/google_oauth2/callback"

    squatter.reload
    expect(squatter.provider).to eq("google_oauth2")
    expect(squatter.uid).to eq("google-ana")
    expect(squatter.email_verified?).to be true
    expect(squatter.authenticate("attacker-password")).to be_falsey
    expect(response).to redirect_to(root_path)
  end

  it "ends the sessions of an unconfirmed account when Google is linked to it" do
    squatter = User.create!(name: "Squatter", email_address: "squatter@example.com", password: "attacker-password")
    attacker_session = squatter.sessions.create!(user_agent: "attacker", ip_address: "203.0.113.9")
    mock_google_auth(uid: "google-ana", email: squatter.email_address, name: "Ana")

    get "/auth/google_oauth2/callback"

    expect(Session.exists?(attacker_session.id)).to be false
    expect(squatter.sessions.count).to eq(1)
    expect(cookies[:session_id]).to be_present
  end

  it "keeps the other sessions of a confirmed account when Google is linked to it" do
    verified = User.create!(name: "Ana", email_address: "ana-verified@example.com", password: "password-123", email_verified_at: Time.current)
    other_session = verified.sessions.create!(user_agent: "laptop", ip_address: "203.0.113.10")
    mock_google_auth(uid: "google-ana-verified", email: verified.email_address, name: "Ana")

    get "/auth/google_oauth2/callback"

    expect(Session.exists?(other_session.id)).to be true
  end

  describe "GET /auth/failure" do
    it "redirects to sign in with an alert" do
      get "/auth/failure"

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq(I18n.t("flashes.oauth.google_sign_in_failed"))
    end
  end
end
