module Marketing
  class JourneyRunner
    def self.run!
      return unless CreamFeatures.enabled?(:journeys)

      JourneyEnrollment.due.includes(:journey, :person, :current_step, :workspace).find_each do |enrollment|
        # Calendar-based steps (task due dates) must use the workspace's day, not UTC's.
        zone = enrollment.workspace.time_zone.presence || IanaTimeZone::DEFAULT_TIME_ZONE
        Time.use_zone(zone) { new(enrollment).advance! }
      rescue => e
        record_runner_error!(enrollment, e)
      end
    end

    def self.record_runner_error!(enrollment, error)
      enrollment.update!(
        metadata: enrollment.metadata.to_h.merge(
          "last_error" => {
            "class" => error.class.name,
            "message" => error.message,
            "at" => Time.current.iso8601
          }
        )
      )
    end

    def initialize(enrollment)
      @enrollment = enrollment
      @journey = enrollment.journey
      @step = resolve_current_step
    end

    def advance!(depth = 0)
      max_depth = [@journey.steps.count, 1].max + 1
      return if depth > max_depth

      return @enrollment.complete! unless @journey.active?
      return @enrollment.complete! if @step.nil?
      return cancel_for_open_deal! if JourneyExit.blocked_by_open_deal?(person: person, journey: journey)

      return advance_past_inactive_step!(depth) unless @step.active?

      case @step.step_type
      when "send_email"
        send_email!
      when "wait"
        wait!(depth)
      when "create_task"
        create_task!
      when "adjust_score"
        adjust_score!
      when "notify"
        notify!
      when "set_field"
        set_field!
      when "branch"
        branch!
      when "add_to_segment"
        add_to_list!
      else
        move_next!
      end
    end

    private

    attr_reader :enrollment, :step

    def person = enrollment.person
    def workspace = enrollment.workspace
    def journey = enrollment.journey

    def send_email!
      email_content = Marketing::EmailContent.from_journey_step(step, workspace: workspace)
      return move_next! unless email_content.present? && person.email.present?

      subscription_type = resolve_subscription_type
      unless Marketing::SendGuard.allowed?(workspace: workspace, address: person.email, subscription_type: subscription_type)
        record_skipped_step!("send_email", reason: "not_allowed")
        return move_next!
      end

      actor = workspace.briefing_actor
      unless actor
        record_step_error!("send_email", "no_briefing_actor")
        return
      end

      message = workspace.email_messages.create!(
        user: actor,
        record: person,
        to_address: person.email,
        subject: email_content.render_subject_for(person),
        body: email_content.render_for(person),
        marketing_send: true
      )
      email_content.attach_to(message)

      delivered = Marketing::Esp::Client.for(message, subscription_type: subscription_type).deliver!
      unless delivered
        message.update!(status: "failed")
        record_step_error!("send_email", "delivery_failed")
        return
      end

      move_next!
    rescue => e
      record_step_error!("send_email", e.message, error_class: e.class.name)
    end

    def wait!(depth = 0)
      if wait_elapsed?
        move_next!
        advance!(depth + 1)
        return
      end

      return if wait_pending?

      enrollment.advance_to!(step, wait_until: wait_until_from_config)
    end

    def wait_elapsed?
      enrollment.state == "waiting" &&
        enrollment.next_run_at.present? &&
        enrollment.next_run_at <= Time.current
    end

    def wait_pending?
      enrollment.state == "waiting" &&
        enrollment.next_run_at.present? &&
        enrollment.next_run_at > Time.current
    end

    # "Until HH:MM" and "weekdays only" are evaluated in the workspace zone,
    # regardless of the Time.zone of the caller.
    def wait_until_from_config
      Marketing::WaitScheduler.new(
        step.config,
        zone: workspace.time_zone.presence || IanaTimeZone::DEFAULT_TIME_ZONE
      ).next_run_at
    end

    def create_task!
      person.tasks.create!(
        workspace: workspace,
        title: step.config["title"].presence || "Journey task",
        due_on: Date.current + step.config.fetch("due_days", 1).to_i.days,
        user: person.owner || workspace.briefing_actor,
        assignee: person.owner || workspace.briefing_actor
      )
      move_next!
    end

    def adjust_score!
      delta = step.config["points"].to_i
      person.update!(lead_score: [person.lead_score + delta, 0].max)
      move_next!
    end

    def notify!
      recipient = workspace.users.find_by(id: step.config["user_id"]) || person.owner
      return move_next! unless recipient

      recipient.notifications.create!(
        workspace: workspace,
        kind: "automation",
        title: journey.name,
        body: step.config["message"].presence || "Journey step completed for #{person.display_name}",
        url: Rails.application.routes.url_helpers.person_path(person)
      )
      move_next!
    end

    def set_field!
      if step.config["field"] == "lifecycle_stage"
        person.update!(lifecycle_stage: step.config["value"])
      end
      move_next!
    end

    def add_to_list!
      list = workspace.lists.find_by(id: step.config["list_id"])
      if list&.record_type == "Person"
        list.list_entries.find_or_create_by!(record: person)
      end
      move_next!
    end

    def branch!
      if Marketing::ConditionEvaluator.new(step.config["condition"] || {}).met_for_person?(person)
        advance_to_target!(journey.steps.active.find_by(id: step.config["true_step_id"]))
      else
        advance_to_target!(journey.steps.active.find_by(id: step.config["false_step_id"]))
      end
    end

    def advance_to_target!(target)
      next_step = target || step.next_step
      return enrollment.complete! unless next_step

      enrollment.advance_to!(next_step)
      @step = next_step
    end

    def advance_past_inactive_step!(depth = 0)
      next_step = step.next_step
      return enrollment.complete! unless next_step

      enrollment.advance_to!(next_step)
      @step = next_step
      advance!(depth + 1)
    end

    def resolve_current_step
      if enrollment.current_step.nil? && enrollment.state == "active"
        return nil
      end

      enrollment.current_step || journey.steps.active.ordered.first
    end

    def resolve_subscription_type
      type_id = step.config["subscription_type_id"]
      if type_id.present?
        workspace.subscription_types.find_by(id: type_id)
      else
        SubscriptionType.ensure_defaults!(workspace)
        workspace.subscription_types.find_by(slug: "general")
      end
    end

    def record_skipped_step!(step_type, reason:)
      metadata = enrollment.metadata.to_h
      skipped = Array(metadata["skipped_steps"])
      skipped << {"step_type" => step_type, "reason" => reason, "at" => Time.current.iso8601}
      enrollment.update!(metadata: metadata.merge("skipped_steps" => skipped))
    end

    def record_step_error!(step_type, message, error_class: nil)
      metadata = enrollment.metadata.to_h
      errors = Array(metadata["step_errors"])
      entry = {"step_type" => step_type, "message" => message, "at" => Time.current.iso8601}
      entry["class"] = error_class if error_class
      errors << entry
      enrollment.update!(metadata: metadata.merge("step_errors" => errors.last(10), "last_error" => entry))
    end

    def move_next!
      next_step = step.next_step
      return enrollment.complete! unless next_step

      enrollment.advance_to!(next_step)
      @step = next_step
    end

    def cancel_for_open_deal!
      enrollment.update!(
        state: "cancelled",
        metadata: enrollment.metadata.merge(
          "cancelled_reason" => "open_deal",
          "cancelled_at" => Time.current.iso8601
        )
      )
    end
  end
end
