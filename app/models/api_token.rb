class ApiToken < ApplicationRecord
  TOKEN_PREFIX = "cream_".freeze
  SCOPES = %w[write read].freeze
  EXPIRY_DAYS = [30, 90, 365].freeze
  DEFAULT_EXPIRY_DAYS = 90

  attribute :expires_at, default: -> { DEFAULT_EXPIRY_DAYS.days.from_now }

  belongs_to :user
  belongs_to :workspace

  validates :name, presence: true
  validates :token_scope, inclusion: {in: SCOPES}
  validates :expires_at, presence: true, on: :create

  # Tokens created before expiry was required have no expires_at and stay valid.
  scope :active, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # The plaintext token is only available right after creation.
  attr_reader :plaintext_token

  before_create :generate_token

  def self.authenticate(plaintext)
    return nil if plaintext.blank?

    active.find_by(token_digest: digest(plaintext))&.tap { |t| t.update_column(:last_used_at, Time.current) }
  end

  def self.digest(plaintext)
    OpenSSL::Digest::SHA256.hexdigest(plaintext)
  end

  def read_only?
    token_scope == "read"
  end

  private

  def generate_token
    @plaintext_token = TOKEN_PREFIX + SecureRandom.urlsafe_base64(32)
    self.token_digest = self.class.digest(@plaintext_token)
  end
end
