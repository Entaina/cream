require "rails_helper"

RSpec.describe "Session expiry", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:user) { users(:one) }

  it "keeps an active session signed in" do
    sign_in_as(user)

    get root_path

    expect(response).not_to redirect_to(new_session_path)
  end

  it "asks to sign in again when the session has expired" do
    sign_in_as(user)
    Current.session.update_column(:expires_at, 1.minute.ago)

    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "extends the expiry of a session in use" do
    sign_in_as(user)
    Current.session.update_column(:expires_at, 10.days.from_now)

    get root_path

    expect(Current.session.reload.expires_at).to be_within(1.minute).of(Session::LIFETIME.from_now)
  end

  it "does not let an expired session authorize OAuth applications" do
    sign_in_as(user)
    Current.session.update_column(:expires_at, 1.minute.ago)

    get "/oauth/authorize"

    expect(response).to redirect_to(new_session_url)
  end
end
