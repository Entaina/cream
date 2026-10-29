# Server-side record behind the portal cookie, so signing out invalidates every copy of it.
class ClientPortalSession < ApplicationRecord
  EXPIRY = 7.days

  belongs_to :workspace

  validates :email, presence: true
  validates :token_digest, presence: true
  validates :expires_at, presence: true

  scope :active, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token.to_s)
  end

  def self.start!(workspace_id:, email:, preview: false)
    raw_token = SecureRandom.urlsafe_base64(32)
    create!(
      workspace_id: workspace_id,
      email: OfferAccessGrant.normalize_email(email),
      preview: preview,
      token_digest: digest(raw_token),
      expires_at: EXPIRY.from_now
    )
    raw_token
  end

  # Returns the existing row (even if revoked) so a copy of a signed-out cookie can't start over.
  def self.adopt_legacy!(raw_token:, workspace_id:, email:, preview:)
    create_or_find_by!(token_digest: digest(raw_token)) do |session|
      session.workspace_id = workspace_id
      session.email = OfferAccessGrant.normalize_email(email)
      session.preview = preview
      session.expires_at = EXPIRY.from_now
    end
  end

  def self.find_active(raw_token)
    return if raw_token.blank?

    active.find_by(token_digest: digest(raw_token))
  end

  def self.revoke(raw_token)
    return if raw_token.blank?

    active.where(token_digest: digest(raw_token)).update_all(revoked_at: Time.current, updated_at: Time.current)
  end
end
