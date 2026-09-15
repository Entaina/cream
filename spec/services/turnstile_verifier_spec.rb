require "rails_helper"

RSpec.describe TurnstileVerifier do
  describe ".enabled?" do
    it "is false without the env keys" do
      expect(described_class.enabled?).to be(false)
    end

    it "is true with both keys set" do
      stub_env_keys
      expect(described_class.enabled?).to be(true)
    end
  end

  describe ".valid?" do
    before { stub_env_keys }

    it "is false for a blank token without calling Cloudflare" do
      allow(Net::HTTP).to receive(:post_form)

      expect(described_class.valid?(token: "")).to be(false)
      expect(Net::HTTP).not_to have_received(:post_form)
    end

    it "is true when Cloudflare confirms the token" do
      stub_cloudflare_response({"success" => true})

      expect(described_class.valid?(token: "ok-token", ip: "203.0.113.1")).to be(true)
      expect(Net::HTTP).to have_received(:post_form).with(
        described_class::VERIFY_URI,
        hash_including("response" => "ok-token", "remoteip" => "203.0.113.1")
      )
    end

    it "is false when Cloudflare rejects the token" do
      stub_cloudflare_response({"success" => false})

      expect(described_class.valid?(token: "bad-token")).to be(false)
    end

    it "fails open when the verification request errors" do
      allow(Net::HTTP).to receive(:post_form).and_raise(Errno::ECONNREFUSED)

      expect(described_class.valid?(token: "any")).to be(true)
    end
  end

  def stub_env_keys
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return("secret-key")
  end

  def stub_cloudflare_response(body)
    allow(Net::HTTP).to receive(:post_form).and_return(instance_double(Net::HTTPOK, body: body.to_json))
  end
end
