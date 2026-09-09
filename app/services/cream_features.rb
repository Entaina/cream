# Single source of truth for Streak-parity features: what is enabled in the UI and routes.
# Update TRACKING.md in .claude/skills/cream-streak-roadmap/ when toggling flags.
module CreamFeatures
  Entry = Data.define(:key, :enabled, :menu, :label, :status, :blockers, :enable_steps)

  REGISTRY = {
    reports: {
      enabled: true,
      menu: true,
      label: "Reports",
      status: :ready,
      blockers: [ "MVP builder (metric/dimension/range, save); no CSV export or scheduled reports yet" ],
      enable_steps: []
    },
    mail_merge: {
      enabled: false,
      menu: false,
      label: "Mail merge",
      status: :ready,
      blockers: [ "Removed from sidebar; segments replace manual ID mail merge" ],
      enable_steps: []
    },
    email_templates: {
      enabled: true,
      menu: true,
      label: "Plantillas",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    record_email: {
      enabled: true,
      menu: false,
      label: "Send email from records",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    email_tracking: {
      enabled: true,
      menu: false,
      label: "Email open/click tracking",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    gmail_addon: {
      enabled: true,
      menu: false,
      label: "Gmail add-on",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    gmail_sync: {
      enabled: true,
      menu: true,
      label: "Gmail",
      status: :partial,
      blockers: [
        "Production Google Cloud verification for restricted scopes",
        "Full reply logging requires gmail.readonly token without gmail.metadata — user may need Enable full reply logging re-auth"
      ],
      enable_steps: [
        "Add gmail.send, gmail.metadata and gmail.readonly in Google Cloud (see deploy/GMAIL_SETUP.md)",
        "Manual test: send from record, Replied badge, Received body after full OAuth + Sync now"
      ]
    },
    automations: {
      enabled: true,
      menu: true,
      label: "Automations",
      status: :ready,
      blockers: [ "notify_slack action is a no-op until slack_integrations is enabled (gated in AutomationEngine)" ],
      enable_steps: []
    },
    alerts: {
      enabled: true,
      menu: true,
      label: "Alertas",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    slack_integrations: {
      enabled: false,
      menu: true,
      label: "Slack",
      status: :partial,
      blockers: [ "Only fires on deal stage change; not on mentions or overdue tasks" ],
      enable_steps: [ "Wire NotificationService events to SlackNotifier", "Set enabled: true" ]
    },
    webhooks: {
      enabled: true,
      menu: true,
      label: "Webhooks",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    comments: {
      enabled: true,
      menu: false,
      label: "Comments",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    attachments: {
      enabled: true,
      menu: false,
      label: "Attachments",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    csv_import_export: {
      enabled: true,
      menu: false,
      label: "CSV import/export",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    notifications: {
      enabled: true,
      menu: false,
      label: "Notifications",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    magic_columns: {
      enabled: true,
      menu: false,
      label: "Magic columns",
      status: :ready,
      blockers: [ "Table index only; not on kanban board" ],
      enable_steps: [ "Add magic columns to deals board cards" ]
    },
    formula_fields: {
      enabled: true,
      menu: false,
      label: "Formula custom fields",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    pipeline_templates: {
      enabled: true,
      menu: false,
      label: "Pipeline templates",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    api_v1: {
      enabled: true,
      menu: false,
      label: "REST API v1",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    ai_assistant: {
      enabled: true,
      menu: false,
      label: "AI Assistant",
      status: :ready,
      blockers: [ "Requires CREAM_AI_API_KEY and the OpenAI Responses API (or compatible endpoint)" ],
      enable_steps: []
    },
    ai_enrichment: {
      enabled: true,
      menu: false,
      label: "AI enrichment",
      status: :partial,
      blockers: [ "Suggestions from existing CRM context only; no external data sources yet" ],
      enable_steps: []
    },
    ai_automations: {
      enabled: false,
      menu: false,
      label: "AI automations",
      status: :placeholder,
      blockers: [ "Proactive AI hooks in AutomationEngine not wired yet" ],
      enable_steps: [ "Add AI automation actions", "Set enabled: true" ]
    },
    sales_director: {
      enabled: true,
      menu: false,
      label: "Sales director",
      status: :ready,
      blockers: [
        "Requires CREAM_AI_API_KEY and the OpenAI Responses API (or compatible endpoint)",
        "Uses OKM and llmemory when configured per workspace in Settings"
      ],
      enable_steps: []
    },
    okm_chat: {
      enabled: true,
      menu: false,
      label: "OKM contextual chat",
      status: :ready,
      blockers: [
        "Requires CREAM_AI_API_KEY and OKM configured per workspace in Settings (Shared Drive ID + service account JSON)"
      ],
      enable_steps: []
    },
    stage_triggers: {
      enabled: true,
      menu: false,
      label: "Stage triggers",
      status: :ready,
      blockers: [ "LLM mode requires CREAM_AI_API_KEY (native functions work without it)" ],
      enable_steps: []
    },
    stage_field_formats: {
      enabled: true,
      menu: false,
      label: "Stage field formats",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    stage_conditions: {
      enabled: true,
      menu: false,
      label: "Stage conditions",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    stripe_payments: {
      enabled: true,
      menu: true,
      label: "Stripe",
      status: :ready,
      blockers: [ "Import-only (no webhooks); refunded is a snapshot at import time" ],
      enable_steps: []
    },
    lead_forms: {
      enabled: true,
      menu: true,
      label: "Formularios",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    calendar_booking: {
      enabled: true,
      menu: true,
      label: "Reservas",
      status: :ready,
      blockers: [
        "Requires Google Calendar OAuth (calendar.readonly + calendar.events scopes) on the booking host",
        "Add both scopes in Google Cloud Console and reconnect after permission changes"
      ],
      enable_steps: [
        "Connect Google Calendar as the page host",
        "Create a booking page with event types and share the public URL"
      ]
    },
    marketing_consent: {
      enabled: true,
      menu: true,
      label: "Suscripciones",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    marketing_campaigns: {
      enabled: true,
      menu: true,
      label: "Campañas",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    marketing_segments: {
      enabled: true,
      menu: true,
      label: "Segmentos",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    marketing_attribution: {
      enabled: true,
      menu: true,
      label: "Atribución",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    journeys: {
      enabled: true,
      menu: true,
      label: "Recorridos",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    lead_scoring: {
      enabled: true,
      menu: true,
      label: "Puntuación de leads",
      status: :ready,
      blockers: [],
      enable_steps: []
    },
    web_tracking: {
      enabled: true,
      menu: false,
      label: "Web tracking",
      status: :ready,
      blockers: [],
      enable_steps: []
    }
  }.freeze

  def self.enabled?(key)
    REGISTRY.fetch(key).fetch(:enabled)
  end

  def self.menu_path(key)
    helper = Rails.application.routes.url_helpers
    case key
    when :reports then helper.reports_path
    when :mail_merge then helper.new_mail_merge_path
    when :email_templates then helper.email_templates_path
    when :gmail_sync then helper.gmail_connection_path
    when :automations then helper.automations_path
    when :alerts then helper.alert_rules_path
    when :slack_integrations then helper.slack_integrations_path
    when :webhooks then helper.webhooks_path
    when :stripe_payments then helper.stripe_payments_path
    when :lead_forms then helper.lead_forms_path
    when :calendar_booking then helper.booking_pages_path
    when :marketing_consent then helper.subscription_types_path
    when :marketing_campaigns then helper.campaigns_path
    when :marketing_segments then helper.segments_path
    when :marketing_attribution then helper.marketing_attribution_path
    when :journeys then helper.journeys_path
    when :lead_scoring then helper.scoring_rules_path
    else raise KeyError, "No menu path for #{key}"
    end
  end

  def self.menu_icon(key)
    {
      reports: :bar_chart,
      mail_merge: :mail,
      email_templates: :mail,
      gmail_sync: :mail,
      automations: :zap,
      alerts: :bell,
      slack_integrations: :message,
      webhooks: :globe,
      stripe_payments: :credit_card,
      lead_forms: :globe,
      calendar_booking: :calendar,
      marketing_consent: :mail,
      marketing_campaigns: :mail,
      marketing_segments: :users,
      marketing_attribution: :bar_chart,
      journeys: :zap,
      lead_scoring: :bar_chart
    }.fetch(key)
  end

  def self.menu_entries
    REGISTRY.select { |_key, meta| meta[:menu] && meta[:enabled] }
  end

  def self.entry(key)
    meta = REGISTRY.fetch(key)
    Entry.new(key: key, **meta)
  end

  def self.all_entries
    REGISTRY.map { |key, meta| Entry.new(key: key, **meta) }
  end
end
