require "rails_helper"

RSpec.describe "Public signup restrictions", type: :request do
  fixtures :workspaces

  around do |example|
    original = ENV["CREAM_PUBLIC_SIGNUP"]
    ENV["CREAM_PUBLIC_SIGNUP"] = "false"
    example.run
  ensure
    if original.nil?
      ENV.delete("CREAM_PUBLIC_SIGNUP")
    else
      ENV["CREAM_PUBLIC_SIGNUP"] = original
    end
  end

  it "blocks registration for unknown domains" do
    get new_registration_path
    expect(response).to redirect_to(new_session_path)

    post registration_path, params: {
      user: {
        name: "Blocked User",
        email_address: "blocked@unknown.test",
        password: "password",
        password_confirmation: "password"
      }
    }

    expect(response).to redirect_to(new_session_path)
    expect(User.find_by(email_address: "blocked@unknown.test")).to be_nil
  end

  it "does not join a workspace email domain until the address is confirmed" do
    workspaces(:one).update!(email_domain: "allowed.test")
    admin = User.create!(
      name: "Admin",
      email_address: "admin@allowed.test",
      password: "password",
      email_verified_at: Time.current
    )
    workspaces(:one).memberships.create!(user: admin, role: "admin")

    expect {
      post registration_path, params: {
        user: {
          name: "Allowed User",
          email_address: "person@allowed.test",
          password: "password",
          password_confirmation: "password"
        }
      }
    }.to have_enqueued_mail(EmailVerificationsMailer, :verify)

    user = User.find_by!(email_address: "person@allowed.test")
    expect(user.email_verified?).to be false
    expect(user.workspaces).to be_empty
    expect(response).to redirect_to(new_session_path)

    post session_path, params: {email_address: user.email_address, password: "password"}
    expect(response).to redirect_to(new_session_path)
    expect(cookies[:session_id]).to be_blank

    get email_verification_path(user.email_verification_token)

    expect(user.reload.email_verified?).to be true
    expect(user.memberships.find_by!(workspace: workspaces(:one)).role).to eq("salesperson")
    expect(response).to redirect_to(root_path)
    expect(cookies[:session_id]).to be_present
  end
end

RSpec.describe "Public signup confirmation", type: :request do
  around do |example|
    original = ENV["CREAM_PUBLIC_SIGNUP"]
    ENV["CREAM_PUBLIC_SIGNUP"] = "true"
    example.run
  ensure
    if original.nil?
      ENV.delete("CREAM_PUBLIC_SIGNUP")
    else
      ENV["CREAM_PUBLIC_SIGNUP"] = original
    end
  end

  it "creates the personal workspace only after the confirmation link is opened" do
    expect {
      post registration_path, params: {
        workspace_name: "Acme Inc",
        user: {
          name: "Jane Doe",
          email_address: "jane@external.test",
          password: "password",
          password_confirmation: "password"
        }
      }
    }.to have_enqueued_mail(EmailVerificationsMailer, :verify)
      .and change(Workspace, :count).by(0)

    user = User.find_by!(email_address: "jane@external.test")
    get email_verification_path(user.email_verification_token)

    expect(user.reload.workspaces.map(&:name)).to contain_exactly("Acme Inc")
    expect(user.memberships.first.role).to eq("admin")
    expect(response).to redirect_to(root_path)
  end
end
