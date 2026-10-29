require "rails_helper"

RSpec.describe SmtpConnection do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }

  before { allow(Resolv).to receive(:getaddresses).and_return(["93.184.216.34"]) }

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

  it "accepts a public host on a submission port" do
    allow(Resolv).to receive(:getaddresses).with("smtp.gmail.com").and_return(["142.250.153.108"])

    expect(build_connection(address: "smtp.gmail.com", port: 587)).to be_valid
  end

  it "only accepts the usual SMTP ports" do
    connection = build_connection(port: 5432)

    expect(connection).not_to be_valid
    expect(connection.errors[:port]).to be_present
    [25, 465, 587, 2525].each { |port| expect(build_connection(port: port)).to be_valid }
  end

  it "rejects hosts in private, loopback or link-local networks" do
    %w[127.0.0.1 10.0.0.5 169.254.169.254].each do |ip|
      allow(Resolv).to receive(:getaddresses).with(ip).and_return([ip])
      connection = build_connection(address: ip)

      expect(connection).not_to be_valid
      expect(connection.errors.details[:address]).to include(error: :must_be_public_host)
    end
  end

  it "rejects a host name that resolves to a private address or does not resolve" do
    allow(Resolv).to receive(:getaddresses).with("db").and_return(["172.18.0.2"])
    allow(Resolv).to receive(:getaddresses).with("nowhere.invalid").and_return([])

    expect(build_connection(address: "db")).not_to be_valid
    expect(build_connection(address: "nowhere.invalid")).not_to be_valid
  end

  it "does not resolve the host again when the address is unchanged" do
    connection = build_connection.tap(&:save!)
    allow(Resolv).to receive(:getaddresses).and_return([])

    expect(connection.update(from_name: "Cream")).to be(true)
  end

  it "refuses delivery settings once the host resolves to a private address" do
    connection = build_connection.tap(&:save!)
    allow(Resolv).to receive(:getaddresses).with("smtp.example.com").and_return(["10.0.0.5"])

    expect { connection.delivery_settings }.to raise_error(SmtpConnection::UnsafeAddressError, /smtp.example.com/)
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
      enable_starttls_auto: true,
      open_timeout: 5,
      read_timeout: 10
    )
  end
end
