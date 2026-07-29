class AlertRulesJob < ApplicationJob
  queue_as :default

  def perform
    Workspace.find_each do |workspace|
      next unless workspace.alert_rules.active.exists?

      AlertRuleEngine.run!(workspace)
    end
  end
end
