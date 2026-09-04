module Marketing
  class ScoringEngine
    LIFECYCLE_THRESHOLDS = {
      "lead" => 10,
      "mql" => 30,
      "sql" => 60,
      "opportunity" => 80
    }.freeze

    MQL_STAGES = %w[mql sql opportunity customer].freeze

    def self.apply_event!(person:, event:, metadata: {})
      return unless CreamFeatures.enabled?(:lead_scoring)

      workspace = person.workspace
      delta = workspace.scoring_rules.active.sum do |rule|
        rule.matches_event?(event, person: person, metadata: metadata) ? rule.points : 0
      end
      return if delta.zero?

      new_score = [ person.lead_score + delta, 0 ].max
      person.update!(lead_score: new_score, lead_score_decayed_at: nil)
      maybe_transition_lifecycle!(person)
      person.track_activity("score_changed", metadata: { "delta" => delta, "score" => new_score, "event" => event }) if person.respond_to?(:track_activity)
    end

    def self.recalculate!(workspace)
      workspace.people.find_each do |person|
        decayed = apply_decay(person)
        person.update!(lead_score: decayed) if decayed != person.lead_score
        maybe_transition_lifecycle!(person)
      end
    end

    def self.apply_decay(person)
      rules = person.workspace.scoring_rules.active.where.not(decay_days: nil)
      return person.lead_score if rules.empty?

      last_activity = person.activities.maximum(:created_at)
      return person.lead_score unless last_activity

      inactive_days = (Time.current - last_activity) / 1.day
      applicable = rules.select { |rule| inactive_days > rule.decay_days }
      return person.lead_score if applicable.empty?

      if person.lead_score_decayed_at.present? && person.lead_score_decayed_at >= last_activity
        return person.lead_score
      end

      decay_total = applicable.sum(&:points) / 2
      [ person.lead_score - decay_total, 0 ].max.tap do |decayed|
        person.update_column(:lead_score_decayed_at, Time.current) if decayed != person.lead_score
      end
    end

    def self.maybe_transition_lifecycle!(person)
      target = LIFECYCLE_THRESHOLDS.select { |_, threshold| person.lead_score >= threshold }.keys.last
      return unless target
      return if lifecycle_rank(target) <= lifecycle_rank(person.lifecycle_stage)

      previous = person.lifecycle_stage
      person.update!(lifecycle_stage: target)
      person.track_activity("lifecycle_changed", metadata: { "from" => previous, "to" => target }) if person.respond_to?(:track_activity)
      JourneyTrigger.enqueue_lifecycle_changed!(person: person, from: previous, to: target)
    end

    def self.lifecycle_rank(stage)
      %w[subscriber lead mql sql opportunity customer evangelist].index(stage) || 0
    end
    private_class_method :lifecycle_rank
  end
end
