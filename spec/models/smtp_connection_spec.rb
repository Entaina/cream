require "rails_helper"

RSpec.describe SmtpConnection do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  def build_connection(**attrs)
    workspace.build_smtp_connection({
      user: user,
      address: "smtp.example.com",
      from_email: "noreply@example.com",
      user_name: "api-key",
      password: "secret-password"
    }.merge(attrs))
  end

  it "defaults to port 587, plain auth and STARTTLS" do
    connection = build_connection
    expect(connection.port).to eq(587)
    expect(connection.authentication).to eq("plain")
    expect(connection.enable_starttls_auto).to be(true)
  end

  it "masks the stored password" do
    connection = build_connection(password: "supersecret")
    expect(connection.masked_password).to eq("supe…cret")
  end

  it "requires a password when a username is set" do
    connection = build_connection(password: nil)
    expect(connection).not_to be_valid
    expect(connection.errors[:password]).to be_present
  end

  it "builds delivery settings from the connection" do
    connection = build_connection(domain: "example.com", port: 2525, authentication: "login")

    expect(connection.delivery_settings).to include(
      address: "smtp.example.com",
      port: 2525,
      user_name: "api-key",
      password: "secret-password",
      domain: "example.com",
      authentication: :login,
      enable_starttls_auto: true
    )
  end
end
