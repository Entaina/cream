module ApplicationHelper
  # Brand color families: Hoki (technology), Copperfield (innovation), Golden Tainoi (people).
  AVATAR_COLORS = [
    %w[bg-hoki-100 text-hoki-700 dark:bg-hoki-900 dark:text-hoki-200],
    %w[bg-copperfield-100 text-copperfield-700 dark:bg-copperfield-900 dark:text-copperfield-200],
    %w[bg-golden-100 text-golden-800 dark:bg-golden-900 dark:text-golden-100],
    %w[bg-chicago-100 text-chicago-700 dark:bg-chicago-800 dark:text-chicago-200],
    %w[bg-hoki-200 text-hoki-800 dark:bg-hoki-800 dark:text-hoki-100],
    %w[bg-copperfield-50 text-copperfield-600 dark:bg-copperfield-950 dark:text-copperfield-300],
    %w[bg-golden-50 text-golden-700 dark:bg-golden-950 dark:text-golden-300],
    %w[bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200]
  ].freeze

  BADGE_COLORS = {
    "chicago" => "bg-chicago-100 text-chicago-700 ring-chicago-200 dark:bg-chicago-800 dark:text-chicago-200 dark:ring-chicago-700",
    "hoki" => "bg-hoki-100 text-hoki-700 ring-hoki-200 dark:bg-hoki-900 dark:text-hoki-200 dark:ring-hoki-800",
    "copperfield" => "bg-copperfield-100 text-copperfield-700 ring-copperfield-200 dark:bg-copperfield-900 dark:text-copperfield-200 dark:ring-copperfield-800",
    "golden" => "bg-golden-100 text-golden-800 ring-golden-300 dark:bg-golden-900 dark:text-golden-100 dark:ring-golden-700",
    "green" => "bg-green-100 text-green-800 ring-green-200 dark:bg-green-900 dark:text-green-200 dark:ring-green-800",
    "red" => "bg-red-100 text-red-800 ring-red-200 dark:bg-red-900 dark:text-red-200 dark:ring-red-800"
  }.freeze

  STAGE_COLUMN_COLORS = {
    "chicago" => "bg-chicago-100 ring-chicago-200 dark:bg-chicago-900 dark:ring-chicago-800",
    "hoki" => "bg-hoki-100 ring-hoki-200 dark:bg-hoki-950 dark:ring-hoki-800",
    "copperfield" => "bg-copperfield-100 ring-copperfield-200 dark:bg-copperfield-950 dark:ring-copperfield-800",
    "golden" => "bg-golden-100 ring-golden-300 dark:bg-golden-950 dark:ring-golden-800",
    "green" => "bg-green-100 ring-green-200 dark:bg-green-950 dark:ring-green-800",
    "red" => "bg-red-100 ring-red-200 dark:bg-red-950 dark:ring-red-800"
  }.freeze

  STAGE_BAR_COLORS = {
    "chicago" => "bg-chicago-300",
    "hoki" => "bg-hoki-300",
    "copperfield" => "bg-copperfield-300",
    "golden" => "bg-golden-300",
    "green" => "bg-green-300",
    "red" => "bg-red-300"
  }.freeze

  def cream_operator_name
    ENV.fetch("CREAM_OPERATOR_NAME", "Example")
  end

  def cream_privacy_email
    ENV.fetch("CREAM_PRIVACY_EMAIL", "privacy@example.com")
  end

  def cream_legal_email
    ENV.fetch("CREAM_LEGAL_EMAIL", "legal@example.com")
  end

  def cream_support_email
    ENV.fetch("CREAM_SUPPORT_EMAIL", "support@example.com")
  end

  def page_title(title)
    content_for(:title) { "#{title} · Cream" }
    title
  end

  # Round avatar with initials, deterministic color per record.
  def avatar(record, size: "size-6", text: "text-2xs")
    colors = AVATAR_COLORS[record.id.to_i % AVATAR_COLORS.size]
    initials = record.respond_to?(:initials) ? record.initials : record.display_name.to_s[0..1].upcase
    shape = record.is_a?(Company) ? "rounded-md" : "rounded-full"
    tag.span(initials, class: [ "inline-flex items-center justify-center font-semibold shrink-0 select-none", shape, size, text, *colors ])
  end

  def badge(label, color: "chicago")
    tag.span(label, class: [ "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap", BADGE_COLORS.fetch(color, BADGE_COLORS["chicago"]) ])
  end

  def stage_column_classes(color)
    STAGE_COLUMN_COLORS.fetch(color, STAGE_COLUMN_COLORS["chicago"])
  end

  def stage_bar_classes(color)
    STAGE_BAR_COLORS.fetch(color, STAGE_BAR_COLORS["chicago"])
  end

  def stage_badge(deal)
    return unless deal.pipeline_stage

    badge(deal.stage_label, color: deal.stage_color)
  end

  def deal_task_indicator(deal)
    task = deal.next_pending_task
    return unless task

    status = deal.pending_task_indicator_status
    color = status == :overdue ? "text-danger" : "text-hoki-600 dark:text-hoki-300"
    pending_count = deal.tasks.count { |t| t.completed_at.nil? }
    label = deal_task_tooltip_label(task, extra_count: pending_count - 1)

    tag.span(class: "relative group shrink-0 #{color}", title: label, aria: { label: label }) do
      safe_join([
        icon(:check_circle, classes: "size-3.5"),
        deal_task_tooltip(task, extra_count: pending_count - 1)
      ])
    end
  end

  def deal_task_tooltip_label(task, extra_count: 0)
    parts = [ task.title ]
    parts << l(task.due_on, format: :short) if task.due_on
    parts << task.assignee.name if task.assignee
    label = parts.join(" · ")
    label += " (+#{extra_count} more)" if extra_count.positive?
    label
  end

  def deal_task_tooltip(task, extra_count: 0)
    tag.span(
      class: "pointer-events-none absolute z-10 top-full right-0 mt-1 w-52 invisible opacity-0 group-hover:visible group-hover:opacity-100 transition-opacity rounded-lg border border-line bg-canvas-raised shadow-md p-2.5 text-left normal-case font-normal",
      role: "tooltip"
    ) do
      safe_join([
        tag.p(class: "text-sm text-ink leading-snug line-clamp-3") { mention_html(task.title) },
        tag.div(class: "mt-1.5 flex items-center gap-2 flex-wrap") do
          safe_join([
            (if task.due_on
               tag.span(class: "text-xs flex items-center gap-1 #{task.overdue? ? "text-danger" : "text-ink-faint"}") do
                 safe_join([ icon(:calendar, classes: "size-3"), l(task.due_on, format: :short) ])
               end
             end),
            (if task.assignee
               tag.span(class: "flex items-center gap-1 text-xs text-ink-faint min-w-0") do
                 safe_join([ avatar(task.assignee, size: "size-4", text: "text-2xs"), tag.span(class: "truncate") { task.assignee.name } ])
               end
             end)
          ].compact)
        end,
        (tag.p("+#{extra_count} more pending", class: "text-xs text-ink-faint mt-1.5") if extra_count.positive?)
      ].compact)
    end
  end

  def stage_filter_options(pipelines, include_closed: false)
    pipelines.map do |pipeline|
      stages = pipeline.pipeline_stages.select { |s| include_closed || !s.closed? }
      [ pipeline.name, stages.map { |s| [ s.name, s.id ] } ]
    end
  end

  def money(amount, currency = "EUR")
    number_to_currency(amount, unit: (currency == "EUR") ? "€" : "$", precision: 0, delimiter: ".", format: "%n %u")
  end

  # Formatted deal field for display, honouring the per-stage display rules
  # (StageFieldFormat) — e.g. price 0 rendered as "guest" in a given stage.
  def deal_field_display(deal, field)
    if feature_enabled?(:stage_field_formats)
      override = StageFieldFormat.display_for(deal, field)
      return override if override
    end

    case field.to_s
    when "value" then money(deal.value, deal.currency)
    when "probability" then deal.probability.present? ? "#{deal.probability}%" : nil
    when "expected_close_date" then deal.expected_close_date && l(deal.expected_close_date, format: :short)
    when "invoice_number" then deal.invoice_number.presence
    end
  end

  # Sortable table header link preserving current filters.
  def sort_link(label, column)
    if respond_to?(:index_query_params, true) || respond_to?(:index_query_params)
      filters = @effective_filters || {}
      sort_val = request.query_parameters["sort"].presence || filters[:sort]
      dir_val = request.query_parameters["dir"].presence || filters[:dir]
      active = sort_val.to_s == column.to_s
      next_dir = (active && dir_val != "desc") ? "desc" : "asc"
      arrow = if active
        icon((dir_val == "desc") ? :chevron_down : :chevron_up, classes: "size-3")
      end
      link_to url_for(index_query_params(sort: column, dir: next_dir)),
        class: "group inline-flex items-center gap-1 hover:text-ink" do
        safe_join([ label, arrow ].compact)
      end
    else
      active = params[:sort] == column.to_s
      next_dir = (active && params[:dir] != "desc") ? "desc" : "asc"
      arrow = if active
        icon((params[:dir] == "desc") ? :chevron_down : :chevron_up, classes: "size-3")
      end
      link_to url_for(request.query_parameters.merge(sort: column, dir: next_dir)),
        class: "group inline-flex items-center gap-1 hover:text-ink" do
        safe_join([ label, arrow ].compact)
      end
    end
  end

  def activity_sentence(activity)
    actor = activity.user&.name || "Someone"
    case activity.action
    when "created" then "#{actor} created this record"
    when "updated"
      fields = (activity.metadata["changes"] || {}).keys.map(&:humanize).join(", ")
      "#{actor} updated #{fields.presence || "the record"}"
    when "note_added" then "#{actor} added a note"
    when "comment_added" then "#{actor} added a comment"
    when "attachment_added" then "#{actor} attached #{activity.metadata["filename"]}"
    when "email_opened" then "#{activity.metadata["to"]} opened “#{activity.metadata["subject"]}”"
    when "email_sent" then "#{actor} sent “#{activity.metadata["subject"]}” to #{activity.metadata["to"]}"
    when "email_clicked" then "Link clicked in “#{activity.metadata["subject"]}”"
    when "email_replied" then "#{activity.metadata["from"] || "Someone"} replied to “#{activity.metadata["subject"]}”"
    when "task_completed" then "#{actor} completed the task “#{activity.metadata["title"]}”"
    when "stage_changed"
      "#{actor} moved the deal from #{activity.metadata["from"]} to #{activity.metadata["to"]}"
    when "pipeline_changed"
      "#{actor} moved the deal to the #{activity.metadata["to"]} pipeline"
    when "contacts_changed"
      contact = activity.metadata["contact"]
      case activity.metadata["change"]
      when "added" then "#{actor} added #{contact} as a contact"
      when "removed" then "#{actor} removed #{contact} as a contact"
      else "#{actor} updated contacts (#{contact})"
      end
    when "merged"
      if activity.metadata["merged_companies"].present?
        names = Array(activity.metadata["merged_companies"]).map { |company|
          label = company["name"]
          label += " (#{company["domain"]})" if company["domain"].present?
          label
        }.join(", ")
        "#{actor} merged #{names} into this record"
      else
        names = Array(activity.metadata["merged_people"]).map { |person|
          label = person["name"]
          label += " (#{person["email"]})" if person["email"].present?
          label
        }.join(", ")
        "#{actor} merged #{names} into this record"
      end
    when "products_changed"
      product = activity.metadata["product"]
      case activity.metadata["change"]
      when "added" then "#{actor} added product line #{product}"
      when "removed" then "#{actor} removed product line #{product}"
      when "updated" then "#{actor} updated product line #{product}"
      else "#{actor} updated products (#{product})"
      end
    when "ai_task_created" then "#{actor} created the AI-suggested task “#{activity.metadata["title"]}”"
    when "payment_received"
      amount = number_to_currency(activity.metadata["amount"],
        unit: activity.metadata["currency"] == "EUR" ? "€" : activity.metadata["currency"],
        precision: 2, delimiter: ".", separator: ",", format: "%n %u")
      "#{actor} linked a Stripe payment of #{amount}#{" from #{activity.metadata["customer_email"]}" if activity.metadata["customer_email"].present?}"
    else "#{actor} #{activity.action.humanize.downcase}"
    end
  end

  def version_actor(version)
    return "Someone" if version.whodunnit.blank?

    User.find_by(id: version.whodunnit)&.name || "Someone"
  end

  def version_sentence(version)
    actor = version_actor(version)
    case version.event
    when "create" then "#{actor} created this deal"
    when "update"
      fields = version.changeset.keys.map(&:humanize).join(", ")
      "#{actor} updated #{fields.presence || "the deal"}"
    when "destroy" then "#{actor} deleted this deal"
    else "#{actor} #{version.event.humanize.downcase} this deal"
    end
  end

  def record_path_for(record)
    case record
    when Person then person_path(record)
    when Company then company_path(record)
    when Deal then deal_path(record)
    end
  end

  def record_icon_for(type)
    { "Person" => :users, "Company" => :building, "Deal" => :banknote }.fetch(type.to_s, :note)
  end

  def sidebar_saved_views_for(record_type)
    return [] unless current_workspace && current_user

    current_workspace.saved_views.visible_to(current_user).for_type(record_type).ordered
  end

  def sidebar_known_keys
    User.sidebar_default_keys
  end

  def sidebar_nav_items
    items_by_key = default_sidebar_nav_items.index_by { |item| item[:key] }
    order = current_user&.sidebar_order || User.sidebar_default_keys
    hidden_keys = current_user&.sidebar_hidden || []

    order.filter_map do |key|
      item = items_by_key[key]
      next unless item

      item.merge(hidden: hidden_keys.include?(key))
    end
  end

  def default_sidebar_nav_items
    base = [
      sidebar_nav_item("dashboard", "Dashboard", root_path, :home, current_page?(root_path)),
      sidebar_nav_item("people", "People", people_path, :users, request.path.start_with?("/people"), sidebar_saved_views_for("Person")),
      sidebar_nav_item("companies", "Companies", companies_path, :building, request.path.start_with?("/companies"), sidebar_saved_views_for("Company")),
      sidebar_nav_item("deals", "Deals", board_deals_path, :banknote, request.path.start_with?("/deals"), sidebar_saved_views_for("Deal")),
      sidebar_nav_item("products", "Products", products_path, :briefcase, request.path.start_with?("/products")),
      sidebar_nav_item("tasks", "Tasks", tasks_path, :check_circle, request.path.start_with?("/tasks"))
    ]

    feature_items = CreamFeatures.menu_entries.map do |key, meta|
      path = CreamFeatures.menu_path(key)
      sidebar_nav_item(key.to_s, meta[:label], path, CreamFeatures.menu_icon(key), request.path.start_with?(path))
    end

    settings = [
      sidebar_nav_item("profile", "Profile", settings_profile_path, :users, request.path.start_with?("/settings/profile")),
      sidebar_nav_item("pipelines", "Pipelines", pipelines_path, :columns, request.path.start_with?("/pipelines")),
      sidebar_nav_item("api_tokens", "API tokens", api_tokens_path, :globe, request.path.start_with?("/api_tokens")),
      sidebar_nav_item("team", "Team", settings_team_path, :users, request.path.start_with?("/settings/team")),
      sidebar_nav_item("custom_fields", "Custom fields", settings_custom_fields_path, :columns, request.path.start_with?("/settings/custom_fields"))
    ]

    base + feature_items + settings
  end

  def sidebar_nav_item(key, label, path, icon_name, active, saved_views = nil)
    { key: key, label: label, path: path, icon: icon_name, active: active, saved_views: saved_views }
  end

  def saved_views_index_path(record_type, view: nil, clear_filters: nil, surface: nil)
    query = {}
    query[:view] = view if view
    query[:clear_filters] = clear_filters if clear_filters
    case record_type
    when "Person" then people_path(query)
    when "Company" then companies_path(query)
    when "Deal" then deal_saved_view_path(query, surface: surface)
    end
  end

  def deal_saved_view_path(query = {}, surface: nil)
    surface == "table" ? deals_path(query) : board_deals_path(query)
  end

  def custom_field_value_display(field, value)
    return nil if value.nil? || (value.is_a?(String) && value.blank?) || (value.is_a?(Array) && value.empty?)

    case field.field_type
    when "formula"
      value.is_a?(Numeric) ? value.round(2) : value
    when "boolean"
      value ? icon(:check, classes: "size-4 text-green-600 dark:text-green-400") : icon(:x, classes: "size-4 text-ink-faint")
    when "currency"
      money(value)
    when "date"
      value.is_a?(Date) ? l(value, format: :short) : l(Date.parse(value.to_s), format: :short)
    when "url"
      link_to(value, value, target: "_blank", class: "text-accent hover:underline break-all")
    when "email"
      mail_to(value, value, class: "text-accent hover:underline")
    when "multi_select"
      safe_join(Array(value).map { |item| badge(item) }, " ")
    when "long_text"
      tag.span(value, class: "whitespace-pre-wrap")
    when "record_reference"
      referenced = resolve_reference_record(field, value)
      return nil unless referenced

      link_to(record_path_for(referenced), class: "inline-flex items-center gap-1.5 text-accent hover:underline") do
        safe_join([ avatar(referenced, size: "size-4", text: "text-2xs"), referenced.public_send(field.reference_label_method) ])
      end
    else
      value.to_s
    end
  rescue ArgumentError
    value.to_s
  end

  def mention_html(text)
    raw MentionParser.render_html(text, workspace: current_workspace)
  end

  def auto_link_html(text)
    raw AutoLinker.render_html(text)
  end

  def resolve_reference_record(field, value)
    return nil if value.blank? || field.reference_type.blank? || current_workspace.nil?

    scope = field.reference_scope(current_workspace)
    scope.find_by(id: value)
  end

  def mention_users_data
    current_workspace.users.order(:name).map do |user|
      { handle: user.email_address.split("@").first, name: user.name }
    end
  end

  def mention_text_field(form, field, **options)
    wrapper_class = options.delete(:wrapper_class) || "flex-1"
    input_class = options.delete(:class) || "input"
    input_data = (options.delete(:data) || {}).merge(
      mention_target: "input",
      action: "input->mention#query keydown->mention#keydown blur->mention#hide"
    )

    tag.div class: "relative #{wrapper_class}", data: {
      controller: "mention",
      mention_users_json_value: mention_users_data.to_json
    } do
      safe_join([
        form.text_field(field, **options, class: input_class, data: input_data),
        tag.ul(
          class: "hidden absolute left-0 right-0 top-full z-50 mt-1 max-h-48 overflow-y-auto rounded-md border border-line bg-canvas shadow-sm",
          data: { mention_target: "menu" },
          role: "listbox"
        )
      ])
    end
  end

  def magic_column_display(record, key)
    value = record.magic_column_value(key)
    case key.to_sym
    when :last_activity_at
      value ? l(value, format: :short) : "—"
    when :days_in_stage
      value.nil? ? "—" : "#{value}d"
    else
      value.nil? ? "—" : value
    end
  end

  def unread_notifications_count
    return 0 unless current_user && current_workspace
    return 0 unless feature_enabled?(:notifications)

    current_user.notifications.where(workspace: current_workspace).unread.count
  end

  def feature_enabled?(key)
    CreamFeatures.enabled?(key)
  end

  def sales_director_enabled?
    current_membership&.sales_director_briefing_visible?
  end

  def okm_chat_enabled?
    feature_enabled?(:okm_chat) &&
      Ai::Configuration.configured? &&
      Okm.configured? &&
      current_workspace&.okm_chat_enabled?
  end

  def okm_chat_context(record = nil)
    return {} unless record

    {
      record_type: Ai::RecordResolver.route_for(record),
      record_id: record.id,
      record_label: record.display_name
    }
  end

  def deal_contact_attribute(deal, attribute)
    deal.contacts.filter_map { |contact| contact.public_send(attribute).presence }.join(", ")
  end
end
