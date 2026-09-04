module Marketing
  class JourneyRunner
    def self.run!
      return unless CreamFeatures.enabled?(:journeys)

      JourneyEnrollment.due.includes(:journey, :person, :current_step).find_each do |enrollment|
        new(enrollment).advance!
      end
    end

    def initialize(enrollment)
      @enrollment = enrollment
      @journey = enrollment.journey
      @step = resolve_current_step
    end

    def advance!
      return @enrollment.complete! unless @journey.active?
      return @enrollment.complete! if @step.nil?

      return advance_past_inactive_step! unless @step.active?

      case @step.step_type
      when "send_email"
        send_email!
      when "wait"
        wait!
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
      template_id = step.config["email_template_id"]
      template = workspace.email_templates.find_by(id: template_id)
      return move_next! unless template && person.email.present?

      subscription_type = resolve_subscription_type
      unless Marketing::SendGuard.allowed?(workspace: workspace, address: person.email, subscription_type: subscription_type)
        record_skipped_step!("send_email", reason: "not_allowed")
        return move_next!
      end

      message = workspace.email_messages.create!(
        user: workspace.briefing_actor,
        record: person,
        to_address: person.email,
        subject: template.render_subject_for(person),
        body: template.render_for(person),
        marketing_send: true
      )
      Marketing::Esp::Client.for(message).deliver!
      move_next!
    end

    def wait!
      if enrollment.state == "waiting" && enrollment.next_run_at.present? && enrollment.next_run_at <= Time.current
        return move_next!
      end

      minutes = step.config["minutes"].to_i
      minutes = 1 if minutes <= 0
      enrollment.advance_to!(step, wait_until: minutes.minutes.from_now)
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
      person.update!(lead_score: [ person.lead_score + delta, 0 ].max)
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
    end

    def advance_past_inactive_step!
      next_step = step.next_step
      return enrollment.complete! unless next_step

      enrollment.advance_to!(next_step)
      @step = next_step
      advance!
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
      skipped << { "step_type" => step_type, "reason" => reason, "at" => Time.current.iso8601 }
      enrollment.update!(metadata: metadata.merge("skipped_steps" => skipped))
    end

    def move_next!
      next_step = step.next_step
      return enrollment.complete! unless next_step

      enrollment.advance_to!(next_step)
    end
  end
end
