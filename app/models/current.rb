class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :workspace
  attribute :pipeline
  attribute :user

  # Web requests set the user through the session. API requests set it directly.
  def user
    @attributes[:user] || session&.user
  end
end
