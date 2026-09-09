require "openssl"
require "base64"

module Marketing
  module Beehiiv
    class SignatureVerifier
      TOLERANCE_SECONDS = 300

      def self.verify!(payload:, headers:, secret:)
        new(payload:, headers:, secret:).verify!
      end

      def initialize(payload:, headers:, secret:)
        @payload = payload
        @headers = headers
        @secret = secret
      end

      def verify!
        raise ArgumentError, "Missing webhook signing secret" if @secret.blank?

        msg_id = header("svix-id")
        msg_timestamp = header("svix-timestamp")
        msg_signature = header("svix-signature")
        raise ArgumentError, "Missing Svix headers" if msg_id.blank? || msg_timestamp.blank? || msg_signature.blank?

        timestamp = Integer(msg_timestamp)
        if (Time.now.to_i - timestamp).abs > TOLERANCE_SECONDS
          raise ArgumentError, "Webhook timestamp outside tolerance"
        end

        signed_content = "#{msg_id}.#{msg_timestamp}.#{@payload}"
        secret_bytes = Base64.decode64(@secret.to_s.sub(/\Awhsec_/, ""))
        expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret_bytes, signed_content))

        valid = msg_signature.split(/\s+/).any? do |versioned_signature|
          version, signature = versioned_signature.split(",", 2)
          version == "v1" && ActiveSupport::SecurityUtils.secure_compare(signature.to_s, expected)
        end

        raise ArgumentError, "Invalid webhook signature" unless valid

        true
      end

      private

      def header(name)
        @headers[name] || @headers[name.tr("-", "_")] ||
          @headers[name.upcase] || @headers["HTTP_#{name.tr("-", "_").upcase}"]
      end
    end
  end
end
