module MarketingHelper
  CAMPAIGN_STATUS_LABELS = {
    "draft" => "Borrador",
    "scheduled" => "Programada",
    "sending" => "Enviando",
    "sent" => "Enviada"
  }.freeze

  CAMPAIGN_STATUS_COLORS = {
    "draft" => "chicago",
    "scheduled" => "golden",
    "sending" => "hoki",
    "sent" => "green"
  }.freeze

  SEND_STATUS_LABELS = {
    "pending" => "Pendiente",
    "scheduled" => "Programado",
    "sending" => "Enviando",
    "sent" => "Enviado",
    "failed" => "Fallido",
    "cancelled" => "Cancelado"
  }.freeze

  ENROLLMENT_STATE_LABELS = {
    "active" => "Activo",
    "waiting" => "En espera",
    "completed" => "Completado",
    "cancelled" => "Cancelado"
  }.freeze

  JOURNEY_TRIGGER_LABELS = {
    "lead_form_submitted" => "Formulario enviado",
    "segment_entry" => "Entrada en segmento",
    "lifecycle_changed" => "Cambio de ciclo de vida",
    "email_clicked" => "Clic en email",
    "booking_created" => "Reserva creada",
    "manual" => "Manual"
  }.freeze

  STEP_TYPE_LABELS = {
    "send_email" => "Enviar email",
    "wait" => "Esperar",
    "create_task" => "Crear tarea",
    "adjust_score" => "Ajustar puntuación",
    "notify" => "Notificar",
    "set_field" => "Establecer campo",
    "branch" => "Condición",
    "add_to_segment" => "Añadir a lista"
  }.freeze

  SCORING_EVENT_LABELS = {
    "email_opened" => "Email abierto",
    "email_clicked" => "Email clicado",
    "email_sent" => "Email enviado",
    "page_view" => "Visita web",
    "lead_submission" => "Formulario enviado",
    "booking_created" => "Reserva creada",
    "deal_created" => "Deal creado",
    "form_field" => "Campo de formulario"
  }.freeze

  SUBSCRIPTION_STATUS_LABELS = {
    "subscribed" => "Suscrito",
    "unsubscribed" => "Dado de baja",
    "pending" => "Pendiente"
  }.freeze

  def campaign_status_badge(status)
    badge(CAMPAIGN_STATUS_LABELS.fetch(status.to_s, status), color: CAMPAIGN_STATUS_COLORS.fetch(status.to_s, "chicago"))
  end

  def send_status_badge(status)
    color = case status.to_s
    when "sent" then "green"
    when "failed" then "red"
    when "scheduled" then "golden"
    else "chicago"
    end
    badge(SEND_STATUS_LABELS.fetch(status.to_s, status), color: color)
  end

  def enrollment_state_badge(state)
    color = case state.to_s
    when "completed" then "green"
    when "waiting" then "golden"
    when "cancelled" then "red"
    else "hoki"
    end
    badge(ENROLLMENT_STATE_LABELS.fetch(state.to_s, state), color: color)
  end

  def journey_trigger_label(trigger)
    JOURNEY_TRIGGER_LABELS.fetch(trigger.to_s, trigger.to_s.humanize)
  end

  def step_type_label(step_type)
    STEP_TYPE_LABELS.fetch(step_type.to_s, step_type.to_s.humanize)
  end

  def scoring_event_label(event_type)
    SCORING_EVENT_LABELS.fetch(event_type.to_s, event_type.to_s.humanize)
  end

  def subscription_status_badge(status)
    color = status.to_s == "subscribed" ? "green" : "chicago"
    badge(SUBSCRIPTION_STATUS_LABELS.fetch(status.to_s, status), color: color)
  end

  def describe_segment_filters(filters)
    filters = filters.to_h.stringify_keys
    parts = []
    parts << "búsqueda «#{filters['q']}»" if filters["q"].present?
    parts << "ciclo #{filters['lifecycle_stage']}" if filters["lifecycle_stage"].present?
    parts << "email contiene «#{filters['email_contains']}»" if filters["email_contains"].present?
    if filters["lead_score_min"].present? || filters["lead_score_max"].present?
      parts << "puntuación #{filters['lead_score_min'] || '…'}-#{filters['lead_score_max'] || '…'}"
    end
    parts << "abrió email (#{filters['opened_email_days']} días)" if filters["opened_email_days"].present?
    parts << "formulario «#{filters['submitted_form_slug']}»" if filters["submitted_form_slug"].present?
    parts << "visitó URL «#{filters['visited_url']}»" if filters["visited_url"].present?
    parts << "sin suprimidos" if filters["exclude_suppressed"].in?([ true, "true", "1", 1 ])
    parts.presence&.join("; ") || "Sin filtros"
  end

  def describe_step(step, workspace:)
    config = step.config.to_h
    case step.step_type
    when "send_email"
      template = workspace.email_templates.find_by(id: config["email_template_id"])
      "Enviar «#{template&.name || 'plantilla'}»"
    when "wait"
      "Esperar #{config['minutes'] || 1} min"
    when "create_task"
      "Tarea: #{config['title'].presence || 'sin título'}"
    when "adjust_score"
      "#{config['points'].to_i >= 0 ? '+' : ''}#{config['points']} pts"
    when "add_to_segment"
      list = workspace.lists.find_by(id: config["list_id"])
      "Añadir a lista «#{list&.name || '…'}»"
    when "branch"
      "Condición → paso #{config['true_step_id'] || 'siguiente'} / #{config['false_step_id'] || 'siguiente'}"
    when "set_field"
      "#{config['field']}: #{config['value']}"
    when "notify"
      "Notificar usuario"
    else
      step_type_label(step.step_type)
    end
  end
end
