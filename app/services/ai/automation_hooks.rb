module Ai
  # Phase 3 placeholder: proactive AI hooks for AutomationEngine and record lifecycle.
  # Wire new automation action types (e.g. ai_summarize, ai_draft_email) here once
  # ai_automations is enabled in CreamFeatures.
  class AutomationHooks
    def self.after_deal_closed(deal:)
      return unless CreamFeatures.enabled?(:ai_automations)

      nil
    end

    def self.after_email_sent(message:)
      return unless CreamFeatures.enabled?(:ai_automations)

      nil
    end

    def self.score_deal(deal:)
      return unless CreamFeatures.enabled?(:ai_automations)

      nil
    end
  end
end
