module MarketingHelper
  CAMPAIGN_STATUS_COLORS = {
    "draft" => "chicago",
    "scheduled" => "golden",
    "sending" => "hoki",
    "sent" => "green"
  }.freeze

  JOURNEY_SEND_STAT_KEYS = %w[blocked max_reenrollments no_steps inactive feature_disabled].freeze

  def campaign_status_badge(status)
    badge(t("marketing.campaign_statuses.#{status}", default: status), color: CAMPAIGN_STATUS_COLORS.fetch(status.to_s, "chicago"))
  end

  def send_status_badge(status)
    color = case status.to_s
    when "sent" then "green"
    when "failed" then "red"
    when "scheduled" then "golden"
    else "chicago"
    end
    badge(t("marketing.send_statuses.#{status}", default: status), color: color)
  end

  def delivery_mode_label(mode)
    t("marketing.delivery_modes.#{mode}", default: mode.to_s.humanize)
  end

  def describe_campaign_send_stats(stats, delivery_mode: "email")
    stats = stats.to_h.stringify_keys
    parts = []

    if delivery_mode.in?(%w[email both]) && (stats["sent"] || stats["skipped"] || stats["failed"])
      parts << t("marketing.send_stats.sent", count: stats["sent"] || 0)
      parts << t("marketing.send_stats.skipped", count: stats["skipped"]) if stats["skipped"].to_i.positive?
      parts << t("marketing.send_stats.failed", count: stats["failed"]) if stats["failed"].to_i.positive?
    end

    if delivery_mode.in?(%w[journey both])
      enrolled = stats["journey_enrolled"].to_i
      parts << t("marketing.send_stats.journey_enrolled", count: enrolled) if enrolled.positive? || delivery_mode == "journey"
      JOURNEY_SEND_STAT_KEYS.each do |key|
        count = stats["journey_#{key}"].to_i
        parts << t("marketing.send_stats.journey_#{key}", count: count) if count.positive?
      end
    end

    parts.presence&.join(", ") || t("marketing.shared.em_dash")
  end

  def enrollment_state_badge(state)
    color = case state.to_s
    when "completed" then "green"
    when "waiting" then "golden"
    when "cancelled" then "red"
    else "hoki"
    end
    badge(t("marketing.enrollment_states.#{state}", default: state), color: color)
  end

  def journey_trigger_label(trigger)
    t("marketing.journey_triggers.#{trigger}", default: trigger.to_s.humanize)
  end

  def step_type_label(step_type)
    t("marketing.step_types.#{step_type}", default: step_type.to_s.humanize)
  end

  def journey_step_label(step, workspace:)
    "#{step.position + 1}. #{describe_step(step, workspace: workspace)}"
  end

  def scoring_event_label(event_type)
    t("marketing.scoring_events.#{event_type}", default: event_type.to_s.humanize)
  end

  def subscription_status_badge(status)
    color = case status.to_s
    when "subscribed" then "green"
    when "pending" then "golden"
    when "missing" then "hoki"
    else "chicago"
    end
    badge(t("marketing.subscription_statuses.#{status}", default: status.to_s), color: color)
  end

  def campaign_engagement_badge(message)
    engagement = message.campaign_engagement
    color = case engagement
    when "clicked" then "hoki"
    when "opened" then "green"
    when "failed" then "red"
    else "chicago"
    end
    badge(t("marketing.campaign_engagement.#{engagement}", default: engagement), color: color)
  end

  def email_event_label(event_type)
    t("marketing.email_events.#{event_type}", default: event_type.to_s.humanize)
  end

  def describe_segment_filters(filters)
    filters = filters.to_h.stringify_keys
    parts = []
    parts << t("marketing.segment_filters.search", q: filters["q"]) if filters["q"].present?
    parts << t("marketing.segment_filters.lifecycle", stage: filters["lifecycle_stage"]) if filters["lifecycle_stage"].present?
    parts << t("marketing.segment_filters.email_contains", value: filters["email_contains"]) if filters["email_contains"].present?
    if filters["lead_score_min"].present? || filters["lead_score_max"].present?
      parts << t("marketing.segment_filters.lead_score",
        min: filters["lead_score_min"] || "…",
        max: filters["lead_score_max"] || "…")
    end
    parts << t("marketing.segment_filters.opened_email", days: filters["opened_email_days"]) if filters["opened_email_days"].present?
    parts << t("marketing.segment_filters.submitted_form", slug: filters["submitted_form_slug"]) if filters["submitted_form_slug"].present?
    parts << t("marketing.segment_filters.visited_url", url: filters["visited_url"]) if filters["visited_url"].present?
    parts << t("marketing.segment_filters.exclude_suppressed") if filters["exclude_suppressed"].in?([true, "true", "1", 1])
    if filters["open_deal"].present? && filters["open_deal"] != "any"
      value = t("marketing.segment_filters.open_deal_values.#{filters["open_deal"]}", default: filters["open_deal"])
      parts << t("marketing.segment_filters.open_deal", value: value)
    end
    parts << t("marketing.segment_filters.open_deal_product", id: filters["open_deal_product_id"]) if filters["open_deal_product_id"].present?
    parts << t("marketing.segment_filters.interest_product", id: filters["interest_product_id"]) if filters["interest_product_id"].present?
    parts << t("marketing.segment_filters.dealt_product", id: filters["dealt_product_id"]) if filters["dealt_product_id"].present?
    parts << t("marketing.segment_filters.lead_form", id: filters["lead_form_id"]) if filters["lead_form_id"].present?
    if filters["capture_destination"].present? && filters["capture_destination"] != "any"
      value = t("marketing.segment_filters.capture_values.#{filters["capture_destination"]}", default: filters["capture_destination"])
      parts << t("marketing.segment_filters.capture_destination", value: value)
    end
    parts.presence&.join("; ") || t("marketing.segment_filters.none")
  end

  def format_journey_wait_duration(minutes)
    total = minutes.to_i
    total = 1 if total <= 0

    days, remainder = total.divmod(1440)
    hours, mins = remainder.divmod(60)

    parts = []
    if days.positive?
      parts << ((days == 1) ? t("marketing.wait_duration.one_day") : t("marketing.wait_duration.n_days", count: days))
    end
    if hours.positive?
      parts << ((hours == 1) ? t("marketing.wait_duration.one_hour") : t("marketing.wait_duration.n_hours", count: hours))
    end
    if mins.positive? || parts.empty?
      parts << ((mins == 1) ? t("marketing.wait_duration.one_minute") : t("marketing.wait_duration.n_minutes", count: mins))
    end

    parts.join(" ")
  end

  def describe_step(step, workspace:)
    config = step.config.to_h
    next_label = t("marketing.journey_steps.next_step")
    case step.step_type
    when "send_email"
      if config["subject"].present? || config["body"].present?
        label = config["subject"].presence || truncate(config["body"].to_s, length: 40)
        t("marketing.journey_steps.send_labeled", label: label)
      else
        template = workspace.email_templates.find_by(id: config["email_template_id"])
        name = template&.name || t("marketing.journey_steps.template_fallback")
        t("marketing.journey_steps.send_template", name: name)
      end
    when "wait"
      t("marketing.journey_steps.wait", duration: format_journey_wait_duration(config["minutes"] || 1))
    when "create_task"
      title = config["title"].presence || t("marketing.journey_steps.task_untitled")
      t("marketing.journey_steps.task", title: title)
    when "adjust_score"
      points = config["points"].to_i
      sign = "+" if points >= 0
      t("marketing.journey_steps.adjust_score", points: "#{sign}#{points}")
    when "add_to_segment"
      list = workspace.lists.find_by(id: config["list_id"])
      t("marketing.journey_steps.add_to_list", name: list&.name || t("marketing.shared.em_dash"))
    when "branch"
      t("marketing.journey_steps.branch",
        true_step: config["true_step_id"] || next_label,
        false_step: config["false_step_id"] || next_label)
    when "set_field"
      t("marketing.journey_steps.set_field", field: config["field"], value: config["value"])
    when "notify"
      t("marketing.journey_steps.notify_user")
    else
      step_type_label(step.step_type)
    end
  end
end
