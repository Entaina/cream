module StageTriggers
  # Enqueues one job per active trigger of the stage a deal just entered.
  # The acting user is captured at enqueue time (GlobalID); via MCP/API there
  # is no session user, so `user` may be nil and UI actions become no-ops.
  class Dispatcher
    def self.call(deal:, stage:, user:)
      stage.stage_triggers.active.ordered.each do |trigger|
        StageTriggerJob.perform_later(trigger, deal, user)
      end
    end
  end
end
