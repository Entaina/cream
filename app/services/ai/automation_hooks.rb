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
      return unless CreamFeatures.enabled?(:lead_scoring)

      deal.contacts.find_each do |person|
        Marketing::ScoringEngine.apply_event!(
          person: person,
          event: "deal_created",
          metadata: { "deal_id" => deal.id, "value" => deal.value }
        )
      end
    end
  end
end
