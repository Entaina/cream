class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "cream_".freeze

  belongs_to :user
  belongs_to :workspace

  validates :name, presence: true

  # The plaintext token is only available right after creation.
  attr_reader :plaintext_token

  before_create :generate_token

  def self.authenticate(plaintext)
    return nil if plaintext.blank?

    find_by(token_digest: digest(plaintext))&.tap { |t| t.update_column(:last_used_at, Time.current) }
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  private

  def generate_token
    @plaintext_token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@plaintext_token)
  end
end
