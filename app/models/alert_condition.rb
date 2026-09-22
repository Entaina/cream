# Additional filter for an alert rule: all active conditions must pass before a deal matches.
class AlertCondition < ApplicationRecord
  include FieldCondition

  belongs_to :workspace
  belongs_to :alert_rule

  before_validation { self.workspace ||= alert_rule&.workspace }

  validate :alert_rule_belongs_to_workspace

  private

  def alert_rule_belongs_to_workspace
    return if alert_rule.nil? || alert_rule.workspace_id == workspace_id

    errors.add(:alert_rule, :must_belong_to_same_workspace)
  end
end
