class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :workspace
  attribute :pipeline
  attribute :user
  # Identifies automated flows (scoring, journeys) that change records without
  # a signed-in user, e.g. {"kind" => "journey", "name" => "Welcome"}.
  attribute :automation

  # Web requests set the user through the session. API requests set it directly.
  def user
    @attributes[:user] || session&.user
  end
end
