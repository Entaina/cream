# Single-use, expiring email tokens: only the SHA256 digest is stored, the raw token travels in the email.
module OneTimeGrant
  extend ActiveSupport::Concern

  # Caps how many emails one link (or one address) can trigger, so public forms can't be used to spam.
  MAX_ISSUED_PER_HOUR = 20

  included do
    validates :email, presence: true
    validates :token_digest, presence: true
    validates :expires_at, presence: true
  end

  class_methods do
    def digest(raw_token)
      Digest::SHA256.hexdigest(raw_token.to_s)
    end

    def build_with_token(**attrs)
      raw_token = SecureRandom.urlsafe_base64(32)
      grant = create!(**attrs, token_digest: digest(raw_token), expires_at: self::EXPIRY.from_now)
      [grant, raw_token]
    end

    def pending_for(raw_token)
      where(token_digest: digest(raw_token), used_at: nil).where("expires_at > ?", Time.current)
    end

    # Atomic, so two concurrent requests can't both use the same token.
    def consume_from(scope, raw_token)
      now = Time.current
      digest_value = digest(raw_token)
      updated = scope.where(token_digest: digest_value, used_at: nil).where("expires_at > ?", now)
        .update_all(used_at: now, updated_at: now)
      return nil if updated.zero?

      scope.find_by!(token_digest: digest_value)
    end

    def issued_too_often?(scope)
      scope.where("created_at > ?", 1.hour.ago).count >= MAX_ISSUED_PER_HOUR
    end
  end
end
