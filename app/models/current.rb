class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :workspace
  attribute :pipeline
  delegate :user, to: :session, allow_nil: true
end
