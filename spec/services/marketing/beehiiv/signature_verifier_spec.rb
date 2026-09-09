require "rails_helper"
require "openssl"
require "base64"

RSpec.describe Marketing::Beehiiv::SignatureVerifier do
  let(:secret) { "whsec_#{Base64.strict_encode64("super-secret-key")}" }
  let(:payload) { '{"event_type":"subscription.created"}' }
  let(:msg_id) { "msg_test123" }
  let(:timestamp) { Time.now.to_i.to_s }

  def signed_headers
    signed_content = "#{msg_id}.#{timestamp}.#{payload}"
    secret_bytes = Base64.decode64(secret.sub(/\Awhsec_/, ""))
    signature = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret_bytes, signed_content))

    {
      "svix-id" => msg_id,
      "svix-timestamp" => timestamp,
      "svix-signature" => "v1,#{signature}"
    }
  end

  it "accepts valid Svix signatures" do
    expect {
      described_class.verify!(payload: payload, headers: signed_headers, secret: secret)
    }.not_to raise_error
  end

  it "rejects invalid signatures" do
    headers = signed_headers.merge("svix-signature" => "v1,invalid")

    expect {
      described_class.verify!(payload: payload, headers: headers, secret: secret)
    }.to raise_error(ArgumentError, /Invalid webhook signature/)
  end
end
