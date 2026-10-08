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

  it "allows registration for a workspace email domain" do
    workspaces(:one).update!(email_domain: "allowed.test")

    post registration_path, params: {
      user: {
        name: "Allowed User",
        email_address: "person@allowed.test",
        password: "password",
        password_confirmation: "password"
      }
    }

    user = User.find_by!(email_address: "person@allowed.test")
    expect(user.workspaces).to include(workspaces(:one))
    expect(response).to redirect_to(root_path)
  end
end
