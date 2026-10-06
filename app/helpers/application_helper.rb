module ApplicationHelper
  # Datetimes are stored in UTC; render them in the request Time.zone (user or
  # workspace). Calendar-only dates (Date) are never shifted.
  def l(object, **options)
    if object.is_a?(Time) || object.is_a?(DateTime)
      super(object.in_time_zone, **options)
    else
      super
    end
  end

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
    tag.span(initials, class: ["inline-flex items-center justify-center font-semibold shrink-0 select-none", shape, size, text, *colors])
  end

  def badge(label, color: "chicago")
    tag.span(label, class: ["inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap", BADGE_COLORS.fetch(color, BADGE_COLORS["chicago"])])
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
    color = (status == :overdue) ? "text-danger" : "text-hoki-600 dark:text-hoki-300"
    pending_count = deal.tasks.count { |t| t.completed_at.nil? }
    label = deal_task_tooltip_label(task, extra_count: pending_count - 1)

    tag.span(class: "relative group shrink-0 #{color}", title: label, aria: {label: label}) do
      safe_join([
        icon(:check_circle, classes: "size-3.5"),
        deal_task_tooltip(task, extra_count: pending_count - 1)
      ])
    end
  end

  def deal_task_tooltip_label(task, extra_count: 0)
    parts = [task.title]
    parts << l(task.due_on, format: :short) if task.due_on
    parts << task.assignee.name if task.assignee
    label = parts.join(" · ")
    label += " (#{t("records.more_pending_short", count: extra_count)})" if extra_count.positive?
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
                 safe_join([icon(:calendar, classes: "size-3"), l(task.due_on, format: :short)])
               end
             end),
            (if task.assignee
               tag.span(class: "flex items-center gap-1 text-xs text-ink-faint min-w-0") do
                 safe_join([avatar(task.assignee, size: "size-4", text: "text-2xs"), tag.span(class: "truncate") { task.assignee.name }])
               end
             end)
          ].compact)
        end,
        (tag.p(t("records.more_pending", count: extra_count), class: "text-xs text-ink-faint mt-1.5") if extra_count.positive?)
      ].compact)
    end
  end

  def lead_form_email_template_tokens_hint
    t("marketing.lead_forms.form.email_tokens_hint")
  end

  def info_tooltip(content, label: t("shared.more_information"), width: "w-72")
    tag.span(class: "relative group shrink-0 inline-flex") do
      safe_join([
        tag.button(
          type: "button",
          class: "inline-flex text-ink-faint hover:text-ink-soft focus:outline-none focus-visible:text-ink",
          aria: {label: label}
        ) { icon(:info, classes: "size-4") },
        tag.span(
          class: "pointer-events-none absolute z-10 right-0 top-full mt-1 #{width} invisible opacity-0 group-hover:visible group-hover:opacity-100 group-focus-within:visible group-focus-within:opacity-100 transition-opacity rounded-lg border border-line bg-canvas-raised shadow-md p-2.5 text-left text-xs text-ink-faint font-normal leading-relaxed",
          role: "tooltip"
        ) { content }
      ])
    end
  end

  def stage_filter_options(pipelines, include_closed: false)
    pipelines.map do |pipeline|
      stages = pipeline.pipeline_stages.select { |s| include_closed || !s.closed? }
      [pipeline.name, stages.map { |s| [s.name, s.id] }]
    end
  end

  def stage_display_name(stage, **_options)
    stage.name
  end

  def stage_summary_dom_id(stage_or_name)
    name = stage_or_name.is_a?(PipelineStage) ? stage_or_name.name : stage_or_name.to_s
    "stage_summary_#{name.parameterize(separator: "_")}"
  end

  def pipeline_bar_color(pipeline_position)
    StageNameGroup.pipeline_bar_colors[pipeline_position.to_i % StageNameGroup.pipeline_bar_colors.size]
  end

  def money(amount, currency = "EUR")
    number = amount.to_d
    number_to_currency(number,
      unit: (currency == "EUR") ? "€" : "$",
      precision: number.frac.zero? ? 0 : 2)
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
    when "execution_duration_days" then format_execution_duration(deal.execution_duration_days)
    when "execution_starts_on" then deal.execution_starts_on && l(deal.execution_starts_on, format: :short)
    when "execution_ends_on" then deal.execution_ends_on && l(deal.execution_ends_on, format: :short)
    when "payment_method" then format_deal_payment_method(deal.payment_method)
    when "payment_on" then deal.payment_on && l(deal.payment_on, format: :short)
    when "invoice_number" then deal.invoice_number.presence
    end
  end

  def format_execution_duration(days)
    return if days.blank?

    t("deals.execution_duration", count: days)
  end

  def format_deal_payment_method(method)
    return if method.blank?

    t("deals.payment_methods.#{method}")
  end

  def board_sort_selected
    sort = filter_value(:sort).to_s
    sort.blank? ? "next_task" : sort
  end

  def board_sort_direction
    filter_value(:dir).presence || "asc"
  end

  def board_deal_sort_options(pipeline:, custom_fields:)
    options = [
      [t("deals.board.sort_next_task"), "next_task"],
      [t("deals.board.sort_manual"), "position"],
      [t("records.fields.name"), "name"],
      [t("records.fields.value"), "value"],
      [t("records.fields.close_date"), "expected_close_date"],
      [t("records.fields.execution_duration"), "execution_duration_days"],
      [t("records.fields.execution_starts_on"), "execution_starts_on"],
      [t("records.fields.execution_ends_on"), "execution_ends_on"],
      [t("records.fields.payment_method"), "payment_method"],
      [t("records.fields.payment_on"), "payment_on"],
      [t("records.fields.invoice_number"), "invoice_number"],
      [t("records.fields.created"), "created_at"]
    ]
    options << [t("records.fields.stage"), "stage"] if pipeline
    custom_fields.each { |field| options << [field.name, "cf:#{field.key}"] }
    options
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
        safe_join([label, arrow].compact)
      end
    else
      active = params[:sort] == column.to_s
      next_dir = (active && params[:dir] != "desc") ? "desc" : "asc"
      arrow = if active
        icon((params[:dir] == "desc") ? :chevron_down : :chevron_up, classes: "size-3")
      end
      link_to url_for(request.query_parameters.merge(sort: column, dir: next_dir)),
        class: "group inline-flex items-center gap-1 hover:text-ink" do
        safe_join([label, arrow].compact)
      end
    end
  end

  def activity_sentence(activity)
    actor = activity.user&.name || t("shared.someone")
    case activity.action
    when "created" then t("activities.created", actor: actor)
    when "updated"
      fields = (activity.metadata["changes"] || {}).keys.map(&:humanize).join(", ")
      t("activities.updated", actor: actor, fields: fields.presence || t("activities.updated_record"))
    when "note_added" then t("activities.note_added", actor: actor)
    when "comment_added" then t("activities.comment_added", actor: actor)
    when "attachment_added" then t("activities.attachment_added", actor: actor, filename: activity.metadata["filename"])
    when "email_opened" then t("activities.email_opened", to: activity.metadata["to"], subject: activity.metadata["subject"])
    when "email_sent" then t("activities.email_sent", actor: actor, subject: activity.metadata["subject"], to: activity.metadata["to"])
    when "email_clicked" then t("activities.email_clicked", subject: activity.metadata["subject"])
    when "email_replied" then t("activities.email_replied", from: activity.metadata["from"] || t("shared.someone"), subject: activity.metadata["subject"])
    when "task_completed" then t("activities.task_completed", actor: actor, title: activity.metadata["title"])
    when "stage_changed"
      t("activities.stage_changed", actor: actor, from: activity.metadata["from"], to: activity.metadata["to"])
    when "pipeline_changed"
      t("activities.pipeline_changed", actor: actor, to: activity.metadata["to"])
    when "contacts_changed"
      contact = activity.metadata["contact"]
      case activity.metadata["change"]
      when "added" then t("activities.contact_added", actor: actor, contact: contact)
      when "removed" then t("activities.contact_removed", actor: actor, contact: contact)
      else t("activities.contacts_updated", actor: actor, contact: contact)
      end
    when "merged"
      if activity.metadata["merged_companies"].present?
        names = Array(activity.metadata["merged_companies"]).map { |company|
          label = company["name"]
          label += " (#{company["domain"]})" if company["domain"].present?
          label
        }.join(", ")
        t("activities.merged_companies", actor: actor, names: names)
      else
        names = Array(activity.metadata["merged_people"]).map { |person|
          label = person["name"]
          label += " (#{person["email"]})" if person["email"].present?
          label
        }.join(", ")
        t("activities.merged_people", actor: actor, names: names)
      end
    when "products_changed"
      product = activity.metadata["product"]
      case activity.metadata["change"]
      when "added" then t("activities.product_added", actor: actor, product: product)
      when "removed" then t("activities.product_removed", actor: actor, product: product)
      when "updated" then t("activities.product_updated", actor: actor, product: product)
      else t("activities.products_updated", actor: actor, product: product)
      end
    when "ai_task_created" then t("activities.ai_task_created", actor: actor, title: activity.metadata["title"])
    when "booking_created"
      instant = Time.zone.parse(activity.metadata["starts_at"].to_s)
      datetime = if instant
        Booking.display_starts_at_with_zone(
          starts_at: instant,
          timezone: activity.metadata["timezone"]
        )
      else
        activity.metadata["starts_at"]
      end
      t("activities.booking_created",
        guest: activity.metadata["guest"].presence || t("shared.someone"),
        event: activity.metadata["event_name"],
        datetime: datetime)
    when "payment_received"
      amount = number_to_currency(activity.metadata["amount"],
        unit: (activity.metadata["currency"] == "EUR") ? "€" : activity.metadata["currency"],
        precision: 2)
      suffix = activity.metadata["customer_email"].present? ? t("activities.payment_received_from", email: activity.metadata["customer_email"]) : ""
      t("activities.payment_received", actor: actor, amount: "#{amount}#{suffix}")
    else t("activities.generic", actor: actor, action: activity.action.humanize.downcase)
    end
  end

  def person_history_activity_html(activity)
    if activity.action == "stage_changed" && activity.subject_type == "Deal" && activity.subject.is_a?(Deal)
      deal = activity.subject
      actor = activity.user&.name || t("shared.someone")
      deal_link = link_to(deal.name, deal_path(deal), class: "font-medium text-accent hover:underline")
      if activity_stage_change_won?(activity)
        t("activities.person_deal_won_html", actor: actor, deal_link: deal_link)
      else
        t("activities.person_deal_stage_changed_html",
          actor: actor, deal_link: deal_link,
          from: activity.metadata["from"], to: activity.metadata["to"])
      end.html_safe
    else
      activity_sentence(activity)
    end
  end

  def activity_stage_change_won?(activity)
    meta = activity.metadata
    return ActiveModel::Type::Boolean.new.cast(meta["won"]) if meta.key?("won")

    deal = activity.subject
    return false unless deal.is_a?(Deal) && meta["to"].present?

    deal.pipeline.pipeline_stages.find_by(name: meta["to"])&.won?
  end

  def version_actor(version)
    return t("shared.someone") if version.whodunnit.blank?

    User.find_by(id: version.whodunnit)&.name || t("shared.someone")
  end

  def version_sentence(version)
    actor = version_actor(version)
    case version.event
    when "create" then t("deal_versions.created", actor: actor)
    when "update"
      fields = version.changeset.keys.map(&:humanize).join(", ")
      t("deal_versions.updated", actor: actor, fields: fields.presence || t("deal_versions.updated_deal"))
    when "destroy" then t("deal_versions.destroyed", actor: actor)
    else t("activities.generic", actor: actor, action: version.event.humanize.downcase)
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
    {"Person" => :users, "Company" => :building, "Deal" => :banknote}.fetch(type.to_s, :note)
  end

  def sidebar_saved_views_for(record_type)
    return [] unless current_workspace && current_user

    current_workspace.saved_views.visible_to(current_user).for_type(record_type).ordered
  end

  def sidebar_known_keys
    current_user&.sidebar_default_keys(admin: sidebar_admin?) || User.sidebar_default_keys(admin: sidebar_admin?)
  end

  def sidebar_admin?
    current_membership&.admin?
  end

  def sidebar_nav_groups
    items_by_key = default_sidebar_nav_items.index_by { |item| item[:key] }
    order = current_user&.sidebar_order(admin: sidebar_admin?) || sidebar_known_keys
    hidden_keys = current_user&.sidebar_hidden(admin: sidebar_admin?) || []

    SidebarMenu.nav_groups(admin: sidebar_admin?).map do |group|
      items = order.filter_map do |key|
        next unless group[:keys].include?(key)

        item = items_by_key[key]
        next unless item

        item.merge(hidden: hidden_keys.include?(key))
      end

      active = items.any? do |item|
        item[:active] || item[:children]&.any? { |child| child[:active] }
      end

      group.merge(items: items, active: active)
    end
  end

  def sidebar_nav_items
    sidebar_nav_groups.flat_map { |group| group[:items] }
  end

  def default_sidebar_nav_items
    SidebarMenu.default_keys(admin: sidebar_admin?).filter_map { |key| sidebar_item_for(key) }
  end

  def sidebar_item_for(key)
    case key
    when "dashboard"
      sidebar_nav_item("dashboard", t("nav.dashboard"), root_path, :home, current_page?(root_path), group: :daily)
    when "people"
      sidebar_nav_item("people", t("nav.people"), people_path, :users, request.path.start_with?("/people"),
        sidebar_saved_view_children("Person"), group: :daily)
    when "companies"
      sidebar_nav_item("companies", t("nav.companies"), companies_path, :building, request.path.start_with?("/companies"),
        sidebar_saved_view_children("Company"), group: :daily)
    when "deals"
      sidebar_nav_item("deals", t("nav.deals"), board_deals_path, :banknote, request.path.start_with?("/deals"),
        sidebar_saved_view_children("Deal"), group: :daily)
    when "tasks"
      sidebar_nav_item("tasks", t("nav.tasks"), tasks_path, :check_circle, request.path.start_with?("/tasks"), group: :daily)
    when "team"
      sidebar_nav_item("team", t("nav.team"), settings_team_path, :users, request.path.start_with?("/settings/team"), group: :settings)
    when "products"
      sidebar_nav_item("products", t("nav.products"), products_path, :briefcase, request.path.start_with?("/products"), group: :settings)
    when "pipelines"
      sidebar_nav_item("pipelines", t("nav.pipelines"), pipelines_path, :columns, request.path.start_with?("/pipelines"), group: :settings)
    when "custom_fields"
      return unless current_workspace&.feature_enabled?(:custom_fields)

      sidebar_nav_item("custom_fields", t("nav.custom_fields"), settings_custom_fields_path, :columns,
        request.path.start_with?("/settings/custom_fields"), group: :settings)
    when "profile"
      sidebar_nav_item("profile", t("nav.profile"), settings_profile_path, :users, request.path.start_with?("/settings/profile"), group: :profile)
    when "workspace"
      return unless sidebar_admin?

      sidebar_nav_item("workspace", t("nav.workspace_settings"), settings_workspace_path, :settings,
        request.path.start_with?("/settings/workspace"), group: :settings)
    when "api_tokens"
      sidebar_nav_item("api_tokens", t("nav.api_tokens"), api_tokens_path, :globe, request.path.start_with?("/api_tokens"), group: :profile)
    when "lists"
      sidebar_nav_item("lists", t("nav.lists"), lists_path, :list, request.path.start_with?("/lists"),
        sidebar_list_children, group: :profile)
    else
      feature_key = key.to_sym
      return unless CreamFeatures.menu_entries.key?(feature_key)
      return unless current_workspace&.feature_enabled?(feature_key)

      path = CreamFeatures.menu_path(feature_key)
      sidebar_nav_item(key, t("nav.features.#{feature_key}"), path, CreamFeatures.menu_icon(feature_key),
        request.path.start_with?(path), group: SidebarMenu.group_for(key))
    end
  end

  def sidebar_saved_view_children(record_type)
    sidebar_saved_views_for(record_type).map do |view|
      {
        label: view.name,
        path: saved_views_index_path(record_type, view: view.id),
        active: params[:view].to_s == view.id.to_s,
        icon: :list
      }
    end
  end

  def sidebar_list_children
    return [] unless current_workspace

    current_workspace.lists.order(:name).map do |list|
      {
        label: list.name,
        path: list_path(list),
        active: current_page?(list_path(list)),
        icon: :list,
        color: list.color
      }
    end
  end

  def sidebar_nav_item(key, label, path, icon_name, active, children = nil, group: nil)
    {key: key, label: label, path: path, icon: icon_name, active: active, children: children, group: group}
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
    (surface == "table") ? deals_path(query) : board_deals_path(query)
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
        safe_join([avatar(referenced, size: "size-4", text: "text-2xs"), referenced.public_send(field.reference_label_method)])
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
      {handle: user.email_address.split("@").first, name: user.name}
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
          data: {mention_target: "menu"},
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
    return current_workspace.feature_enabled?(key) if current_workspace

    (key.to_sym == :custom_fields) ? false : CreamFeatures.enabled?(key)
  end

  def sales_director_enabled?
    current_membership&.sales_director_briefing_visible?
  end

  def okm_chat_enabled?
    feature_enabled?(:okm_chat) &&
      Ai::Configuration.configured? &&
      current_workspace&.okm_configured? &&
      current_workspace.okm_chat_enabled?
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
