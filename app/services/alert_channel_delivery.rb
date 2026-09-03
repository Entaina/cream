class AlertChannelDelivery
  def self.for(user:, workspace:)
    new(workspace.memberships.find_by(user: user))
  end

  def initialize(membership)
    @membership = membership
  end

  def deliver
    return false unless enabled?

    yield self
    true
  end

  def enabled?
    in_app? || email?
  end

  def in_app?
    @membership&.alert_in_app? || false
  end

  def email?
    @membership&.alert_email? || false
  end
end
