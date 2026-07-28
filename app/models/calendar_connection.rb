class CalendarConnection < ApplicationRecord
  READONLY_SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
  EVENTS_SCOPE = "https://www.googleapis.com/auth/calendar.events"
  OAUTH_SCOPES = [ READONLY_SCOPE, EVENTS_SCOPE ].freeze

  belongs_to :workspace
  belongs_to :user

  validates :user_id, uniqueness: { scope: :workspace_id }

  def connected? = refresh_token.present?

  def expired?
    expires_at.blank? || expires_at <= Time.current
  end

  def scopes
    granted_scopes.to_s.split
  end

  def can_list_calendars?
    return true if granted_scopes.blank?

    scopes.include?(READONLY_SCOPE)
  end

  def can_manage_events?
    return true if granted_scopes.blank?

    scopes.include?(EVENTS_SCOPE)
  end

  def operational?
    connected? && can_list_calendars? && can_manage_events?
  end

  def missing_scopes_message
    missing = []
    missing << "listar calendarios" unless can_list_calendars?
    missing << "crear eventos" unless can_manage_events?
    return if missing.empty?

    "Faltan permisos para #{missing.to_sentence}. Vuelve a conectar Google Calendar."
  end

  def assign_oauth_credentials(auth)
    credentials = auth.credentials
    assign_attributes(
      email: auth.info.email,
      access_token: credentials.token,
      expires_at: credentials.expires_at ? Time.zone.at(credentials.expires_at) : nil
    )
    self.refresh_token = credentials.refresh_token if credentials.refresh_token.present?
    return if credentials.scope.blank?

    merge_granted_scopes!(credentials.scope)
  end

  private

  def merge_granted_scopes!(new_scope_string)
    merged = (scopes + new_scope_string.to_s.split).uniq
    self.granted_scopes = merged.join(" ")
  end
end
