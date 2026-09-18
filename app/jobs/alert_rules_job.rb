class AlertRulesJob < ApplicationJob
  queue_as :default

  def perform
    Workspace.find_each do |workspace|
      next unless workspace.alert_rules.active.exists?

      Time.use_zone(workspace.time_zone.presence || IanaTimeZone::DEFAULT_TIME_ZONE) do
        AlertRuleEngine.run!(workspace)
      end
    end
  end
end
