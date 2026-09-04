module Marketing
  class JourneyTrigger
    def self.enqueue_lead_form_submitted!(person:, lead_form:)
      trigger!("lead_form_submitted", person: person, config_match: { "lead_form_id" => lead_form.id })
    end

    def self.enqueue_booking_created!(person:, booking:)
      trigger!("booking_created", person: person, config_match: { "booking_page_id" => booking.booking_page_id })
    end

    def self.enqueue_email_clicked!(person:)
      trigger!("email_clicked", person: person)
    end

    def self.enqueue_lifecycle_changed!(person:, from:, to:)
      trigger!("lifecycle_changed", person: person, config_match: { "from" => from, "to" => to })
    end

    def self.enqueue_segment_entry!(person:, segment:)
      trigger!("segment_entry", person: person, config_match: { "segment_id" => segment.id })
    end

    def self.trigger!(entry_trigger, person:, config_match: {})
      return unless CreamFeatures.enabled?(:journeys)

      workspace = person.workspace
      workspace.journeys.active.where(entry_trigger: entry_trigger).find_each do |journey|
        next unless config_matches?(journey.entry_config, config_match)
        next if max_reenrollments_reached?(journey, person)

        first_step = journey.steps.active.ordered.first
        next unless first_step

        JourneyEnrollment.create!(
          workspace: workspace,
          journey: journey,
          person: person,
          current_step: first_step,
          state: "active",
          enrolled_at: Time.current,
          next_run_at: Time.current
        )
      end
    end

    def self.config_matches?(entry_config, config_match)
      config = entry_config.to_h.stringify_keys
      config_match.all? do |key, value|
        configured = config[key.to_s]
        next true if configured.blank?

        configured.to_s == value.to_s
      end
    end
    private_class_method :config_matches?

    def self.max_reenrollments_reached?(journey, person)
      count = journey.enrollments.where(person: person).count
      journey.max_reenrollments.positive? && count >= journey.max_reenrollments
    end
    private_class_method :max_reenrollments_reached?
  end
end
