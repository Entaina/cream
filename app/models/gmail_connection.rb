class GmailConnection < ApplicationRecord
  SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"
  METADATA_SCOPE = "https://www.googleapis.com/auth/gmail.metadata"
  READONLY_SCOPE = "https://www.googleapis.com/auth/gmail.readonly"

  belongs_to :workspace
  belongs_to :user

  validates :user_id, uniqueness: { scope: :workspace_id }

  # Connected once we hold a refresh token — that's what lets us send without
  # the user present (an access token alone expires within an hour).
  def connected? = refresh_token.present?

  def expired?
    expires_at.blank? || expires_at <= Time.current
  end

  def scopes
    granted_scopes.to_s.split
  end

  # Legacy connections (granted_scopes nil) predate scope tracking; assume send worked.
  def can_send?
    return true if granted_scopes.blank?

    scopes.include?(SEND_SCOPE)
  end

  def can_read_metadata?
    scopes.include?(METADATA_SCOPE) || scopes.include?(READONLY_SCOPE)
  end

  def can_read_body?
    scopes.include?(READONLY_SCOPE)
  end

  def send_only_mode?
    can_send? && !can_read_metadata?
  end

  def send_and_receive_mode?
    can_send? && can_read_metadata? && !can_read_body?
  end

  def send_receive_full_mode?
    can_send? && can_read_body?
  end

  # Google treats metadata as restrictive even when readonly is also granted:
  # search queries and format=full are blocked until the user reconnects with
  # send + readonly only (no metadata on the token).
  def full_read_blocked_by_metadata?
    scopes.include?(METADATA_SCOPE) && scopes.include?(READONLY_SCOPE)
  end

  GMAIL_API_SCOPES = [ SEND_SCOPE, METADATA_SCOPE, READONLY_SCOPE ].freeze

  # Stores tokens from an OmniAuth Gmail callback. Google only returns a refresh
  # token on the first consent, so keep the existing one if a re-auth omits it.
  def assign_oauth_credentials(auth, mode: nil)
    credentials = auth.credentials
    assign_attributes(
      email: auth.info.email,
      access_token: credentials.token,
      expires_at: credentials.expires_at ? Time.zone.at(credentials.expires_at) : nil
    )
    self.refresh_token = credentials.refresh_token if credentials.refresh_token.present?
    return if credentials.scope.blank?

    if mode.to_s == "full"
      replace_gmail_scopes!(credentials.scope)
    else
      merge_granted_scopes!(credentials.scope)
    end
  end

  private

  def merge_granted_scopes!(new_scope_string)
    merged = (scopes + new_scope_string.to_s.split).uniq
    self.granted_scopes = merged.join(" ")
  end

  def replace_gmail_scopes!(new_scope_string)
    preserved = scopes.reject { |scope| GMAIL_API_SCOPES.include?(scope) }
    incoming_gmail = new_scope_string.to_s.split & GMAIL_API_SCOPES
    self.granted_scopes = (preserved + incoming_gmail).uniq.join(" ")
  end
end
