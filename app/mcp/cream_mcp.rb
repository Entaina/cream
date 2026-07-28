# Builds the MCP server exposing Cream's CRM to AI clients.
# Every tool is scoped to the workspace/user resolved from the access token.
module CreamMcp
  RECORD_TYPES = %w[person company deal].freeze
  MAX_LIST_LIMIT = 100
  DEFAULT_LIST_LIMIT = 25
  MY_TASKS_DEFAULT_LIMIT = 50
  SIGNIFICANT_ACTIONS = %w[
    stage_changed pipeline_changed contacts_changed products_changed
    note_added comment_added task_completed email_replied
  ].freeze

  def self.server_for(user:, workspace:)
    MCP::Server.new(
      name: "cream",
      title: "Cream CRM",
      version: "1.0.0",
      instructions: "CRM with people, companies and deals organised in pipelines with " \
                    "configurable stages (#{workspace.pipeline_stages.ordered.pluck(:name).uniq.join(", ")}). " \
                    "There may be several pipelines — use list_pipelines to discover them and the valid stage names. " \
                    "Deals carry product line items; manage the catalogue with list_products/create_product and " \
                    "add lines with add_deal_product (the deal value is the sum of its line subtotals). " \
                    "Records can be edited with update_person/update_company/update_deal (update_deal also " \
                    "replaces contacts and moves the deal to another pipeline). " \
                    "Duplicate cleanup: list_person_duplicates/list_company_duplicates to find candidates, " \
                    "then merge_person/merge_company (secondaries are deleted after reassignment). " \
                    "delete_record permanently removes a person, company or deal (deleting a company also " \
                    "deletes its people and deals). " \
                    "There are also notes, comments (add_comment for the internal discussion thread), " \
                    "tasks, emails (list_emails; get_email for the full body), " \
                    "Stripe payments (list_payments for imported charges and reconciliation status) and " \
                    "an activity timeline (list_activity). Use recent_changes for a consolidated feed of what " \
                    "happened recently (new records, inbound emails, significant changes) and sales_forecast for " \
                    "weighted pipeline projections by expected close month. Records can have workspace-defined " \
                    "custom fields — use list_custom_fields to discover their keys/types and set_custom_fields " \
                    "to update them. Tool routing: for your own tasks due today or overdue (title + url), use " \
                    "list_my_tasks only — do not use natural_language_search or get_record for that. Tasks on a " \
                    "specific record → list_tasks with record_type and record_id or record_query (name). Tasks " \
                    "assigned to a workspace member → list_tasks with assignee_id or assignee_query. Phrase searches (stalled deals, " \
                    "follow-ups) → natural_language_search. Record detail → get_record. Pipeline overview → " \
                    "pipeline_summary or sales_forecast. People, companies and deals include a url field " \
                    "pointing to the record in the Cream web app (requires CREAM_APP_URL). " \
                    "All data belongs to the workspace «#{workspace.name}».",
      tools: tools,
      server_context: { user: user, workspace: workspace }
    )
  end

  def self.tools
    [ SEARCH, LIST_PEOPLE, LIST_COMPANIES, LIST_DEALS, GET_RECORD,
      LIST_PRODUCTS, LIST_TASKS, LIST_MY_TASKS, LIST_EMAILS, GET_EMAIL, LIST_ACTIVITY, LIST_PAYMENTS, LIST_PIPELINES,
      CREATE_PERSON, CREATE_COMPANY, CREATE_DEAL,
      UPDATE_PERSON, UPDATE_COMPANY, UPDATE_DEAL, UPDATE_DEAL_STAGE,
      LIST_PERSON_DUPLICATES, LIST_COMPANY_DUPLICATES, MERGE_PERSON, MERGE_COMPANY, DELETE_RECORD,
      CREATE_PRODUCT, UPDATE_PRODUCT, ADD_DEAL_PRODUCT, UPDATE_DEAL_PRODUCT, UPDATE_TASK,
      ADD_NOTE, ADD_COMMENT, CREATE_TASK, COMPLETE_TASK, PIPELINE_SUMMARY,
      LIST_CUSTOM_FIELDS, SET_CUSTOM_FIELDS, GET_DEAL_HISTORY,
      RECENT_CHANGES, SALES_FORECAST,
      SUMMARIZE_RECORD, SUGGEST_NEXT_STEPS, DRAFT_EMAIL, NATURAL_LANGUAGE_SEARCH, ENRICH_RECORD ]
  end

  def self.respond_with(payload)
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate(payload) } ])
  end

  def self.list_limit(args, default = DEFAULT_LIST_LIMIT)
    raw = arg(args, "limit")
    (raw.nil? ? default : raw.to_i).clamp(1, MAX_LIST_LIMIT)
  end

  def self.record_path_for(record)
    helpers = Rails.application.routes.url_helpers
    case record
    when Person then helpers.person_path(record)
    when Company then helpers.company_path(record)
    when Deal then helpers.deal_path(record)
    end
  end

  def self.record_url(record)
    path = record_path_for(record)
    return nil unless path

    base = ENV["CREAM_APP_URL"].presence
    base ? "#{base.chomp("/")}#{path}" : path
  end

  def self.record_ref_json(record)
    { type: record.class.name.downcase, id: record.id, name: record.display_name, url: record_url(record) }.compact
  end

  def self.task_url(task)
    if task.taskable
      record_url(task.taskable)
    else
      path = Rails.application.routes.url_helpers.tasks_path
      base = ENV["CREAM_APP_URL"].presence
      base ? "#{base.chomp("/")}#{path}" : path
    end
  end

  def self.person_json(p)
    { id: p.id, type: "person", name: p.display_name, email: p.email, phone: p.phone,
     job_title: p.job_title, location: p.location, company_id: p.company_id,
     company: p.company&.name, owner: p.owner&.name, url: record_url(p),
     custom_fields: custom_fields_json(p) }.compact
  end

  def self.company_json(c)
    { id: c.id, type: "company", name: c.name, domain: c.domain, industry: c.industry,
     employees: c.employee_range, location: c.location, annual_revenue: c.annual_revenue,
     fiscal_information: c.fiscal_information,
     owner: c.owner&.name, people_count: c.people.size, url: record_url(c),
     custom_fields: custom_fields_json(c) }.compact
  end

  def self.deal_json(d)
    line_items = d.association(:deal_products).loaded? ? d.deal_products : d.deal_products.includes(:product, :edition)
    { id: d.id, type: "deal", name: d.name, pipeline: d.pipeline&.name, stage: d.stage_label,
     value: d.value.to_f, currency: d.currency, probability: d.probability,
     products: line_items.map { |lp| { line_item_id: lp.id, product_id: lp.product_id, name: lp.product.name, edition: lp.edition&.name, quantity: lp.quantity, unit_price: lp.unit_price.to_f, subtotal: lp.subtotal.to_f }.compact }.presence,
     expected_close_date: d.expected_close_date&.iso8601,
     company_id: d.company_id, company: d.company&.name, company_url: record_url(d.company),
     contacts: d.contacts.map { |p| record_ref_json(p) }.presence, owner: d.owner&.name, url: record_url(d),
     custom_fields: custom_fields_json(d) }.compact
  end

  def self.custom_fields_json(record)
    record.custom_fields_hash.compact.presence
  end

  def self.custom_field_definition_json(field)
    { key: field.key, name: field.name, type: field.field_type,
     required: field.required, options: field.options.presence }.compact
  end

  def self.task_json(t)
    { id: t.id, title: t.title, due_on: t.due_on&.iso8601, completed: t.completed?,
     overdue: t.overdue?, assignee: t.assignee&.name, url: task_url(t),
     record: t.taskable && record_ref_json(t.taskable) }.compact
  end

  def self.product_json(p)
    { id: p.id, name: p.name, price: p.price.to_f, description: p.description }.compact
  end

  def self.payment_json(p)
    { id: p.id, amount: p.amount_decimal, currency: p.currency.upcase,
      status: p.status, customer_name: p.customer_name, customer_email: p.customer_email,
      description: p.description, paid_at: p.paid_at.iso8601,
      refunded: p.refunded, partially_refunded: p.partially_refunded?,
      amount_refunded: (p.amount_refunded_decimal if p.partially_refunded?),
      payment_method: p.payment_method_summary, receipt_url: p.receipt_url,
      livemode: p.livemode, match_confidence: p.match_confidence,
      deal: p.deal && record_ref_json(p.deal),
      suggested_deal: p.suggested_deal && record_ref_json(p.suggested_deal),
      suggested_person: p.suggested_person && record_ref_json(p.suggested_person),
      stripe_charge_id: p.stripe_charge_id }.compact
  end

  def self.email_json(e)
    { id: e.id, subject: e.subject, to: e.to_address, status: e.status,
     record: e.record && record_ref_json(e.record),
     opened: e.opened?, replied: e.replied?, awaiting_follow_up: e.awaiting_follow_up?,
     follow_up_at: e.follow_up_at&.iso8601, scheduled_at: e.scheduled_at&.iso8601,
     clicks: e.clicks_count, created_at: e.created_at.iso8601 }.compact
  end

  def self.email_detail_json(e)
    email_json(e).merge(
      direction: e.direction, from: e.from_address, body: e.body,
      in_reply_to_id: e.in_reply_to_id,
      replies: e.replies.recent_first.map { |r|
        { id: r.id, direction: r.direction, from: r.from_address, subject: r.subject, created_at: r.created_at.iso8601 }.compact
      }.presence
    ).compact
  end

  def self.comment_json(c)
    { id: c.id, body: c.body, author: c.user.name, parent_id: c.parent_id,
     created_at: c.created_at.iso8601 }.compact
  end

  def self.event_email_json(e)
    { id: e.id, direction: e.direction, from: e.from_address, subject: e.subject,
     record: e.record && record_ref_json(e.record),
     created_at: e.created_at.iso8601 }.compact
  end

  def self.deal_probability(deal)
    deal.probability.nil? ? (deal.pipeline_stage&.probability || 0) : deal.probability
  end

  def self.deal_weighted_value(deal)
    deal.value.to_f * deal_probability(deal) / 100.0
  end

  def self.activity_json(a)
    { action: a.action, by: a.user&.name, at: a.created_at.iso8601,
     subject: activity_subject_json(a),
     details: a.metadata.presence }.compact
  end

  def self.activity_subject_json(activity)
    subject = activity.subject
    return nil unless subject

    if subject.is_a?(Person) || subject.is_a?(Company) || subject.is_a?(Deal)
      record_ref_json(subject)
    else
      { type: activity.subject_type.downcase, id: activity.subject_id, name: subject.display_name }
    end
  end

  def self.deal_version_json(version, users_by_id = {})
    actor = version.whodunnit.present? ? users_by_id[version.whodunnit.to_i] : nil
    { kind: "version", event: version.event, by: actor&.name || "Someone", at: version.created_at.iso8601,
     changes: version.changeset.transform_values { |pair| { from: pair[0], to: pair[1] } }.presence }.compact
  end

  def self.pipeline_json(pl)
    { id: pl.id, name: pl.name, default: pl.default_pipeline,
     stages: pl.pipeline_stages.ordered.map { |s|
       { id: s.id, name: s.name, probability: s.probability, won: s.won, closed: s.closed }
     } }
  end

  def self.cream_context(server_context)
    server_context.instance_variable_get(:@context)
  end

  def self.pundit_context(server_context)
    ctx = cream_context(server_context)
    UserContext.new(user: ctx[:user], workspace: ctx[:workspace])
  end

  def self.authorize!(pundit_ctx, record, query)
    Pundit.authorize(pundit_ctx, record, query)
  end

  def self.policy_scope(pundit_ctx, scope)
    Pundit.policy_scope(pundit_ctx, scope)
  end

  def self.with_authorization(server_context, tool: nil, &block)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) if tool
    block.call
  rescue Pundit::NotAuthorizedError => e
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate({ error: "forbidden", message: e.message }) } ])
  ensure
    if tool
      duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      Rails.logger.info("[MCP] tool=#{tool} duration_ms=#{duration_ms}")
    end
  end

  def self.ai_assistant_enabled?
    CreamFeatures.enabled?(:ai_assistant) && Ai::Configuration.configured?
  end

  def self.ai_unavailable_response
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate({
      error: "ai_unavailable",
      message: "AI assistant is disabled or CREAM_AI_API_KEY is not configured"
    }) } ])
  end

  def self.payments_unavailable_response
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate({
      error: "payments_unavailable",
      message: "Stripe payments feature is disabled"
    }) } ])
  end

  def self.comments_unavailable_response
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate({
      error: "comments_unavailable",
      message: "Comments feature is disabled"
    }) } ])
  end

  def self.arg(args, key)
    args[key] || args[key.to_sym]
  end

  def self.picked(args, *keys)
    keys.index_with { |key| arg(args, key) }.compact
  end

  def self.find_record(workspace, type, id)
    case type.to_s.downcase
    when "person" then workspace.people.find(id)
    when "company" then workspace.companies.find(id)
    when "deal" then workspace.deals.find(id)
    else raise ArgumentError, "record_type must be one of: #{RECORD_TYPES.join(", ")}"
    end
  end

  def self.error_response(error, message)
    MCP::Tool::Response.new([ { type: "text", text: JSON.generate({ error: error, message: message }) } ])
  end

  def self.record_search_scope(workspace, type, query)
    case type.to_s.downcase
    when "person" then workspace.people.search(query)
    when "company" then workspace.companies.search(query)
    when "deal" then workspace.deals.search(query)
    else raise ArgumentError, "record_type must be one of: #{RECORD_TYPES.join(", ")}"
    end
  end

  def self.resolve_record_for_tasks(workspace, type, id: nil, query: nil)
    if id.present?
      find_record(workspace, type, id)
    elsif query.present?
      scope = record_search_scope(workspace, type, query)
      count = scope.count
      if count.zero?
        raise ActiveRecord::RecordNotFound, "No #{type} matching '#{query}'"
      elsif count > 1
        names = scope.limit(5).map(&:display_name).join(", ")
        raise ArgumentError, "Multiple #{type} records match '#{query}': #{names}. Use record_id to disambiguate."
      else
        scope.first
      end
    else
      raise ArgumentError, "record_id or record_query is required when record_type is set"
    end
  end

  def self.workspace_user_search_scope(workspace, query)
    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    workspace.users.where("users.name ILIKE :q OR users.email_address ILIKE :q", q: q)
  end

  def self.resolve_assignee(workspace, id: nil, query: nil)
    if id.present?
      workspace.users.find(id)
    elsif query.present?
      scope = workspace_user_search_scope(workspace, query)
      count = scope.count
      if count.zero?
        raise ActiveRecord::RecordNotFound, "No workspace user matching '#{query}'"
      elsif count > 1
        names = scope.limit(5).map(&:name).join(", ")
        raise ArgumentError, "Multiple users match '#{query}': #{names}. Use assignee_id to disambiguate."
      else
        scope.first
      end
    end
  end

  def self.open_deals_for_record(record, deals_scope)
    case record
    when Company
      deals_scope.where(company_id: record.id).open_deals.order(:name)
    when Person
      deals_scope.joins(:contacts).where(people: { id: record.id }).open_deals.distinct.order(:name)
    else
      Deal.none
    end
  end

  def self.open_deal_tasks_json(scope, record, deals_scope, limit:)
    open_deals = open_deals_for_record(record, deals_scope).to_a
    return [] if open_deals.empty?

    deal_ids = open_deals.map(&:id)
    tasks_by_deal = scope.where(taskable_type: "Deal", taskable_id: deal_ids).due_order.group_by(&:taskable_id)
    remaining = limit

    open_deals.filter_map do |deal|
      next if remaining <= 0

      tasks = (tasks_by_deal[deal.id] || []).first(remaining)
      remaining -= tasks.size
      next if tasks.empty?

      { deal: record_ref_json(deal), tasks: tasks.map { |t| task_json(t) } }
    end
  end

  def self.record_tasks_payload(scope, record, deals_scope, limit:)
    {
      tasks: scope.where(taskable: record).limit(limit).map { |t| task_json(t) },
      open_deal_tasks: open_deal_tasks_json(scope, record, deals_scope, limit: limit)
    }
  end

  SEARCH = MCP::Tool.define(
    name: "search_records",
    description: "Search people, companies and deals by name, email, domain, industry or title.",
    input_schema: { type: "object",
                   properties: { query: { type: "string", description: "Search text" } },
                   required: [ "query" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      ws = ctx.workspace
      CreamMcp.authorize!(ctx, ws, :search?)
      q = CreamMcp.arg(args, "query")
      CreamMcp.respond_with(
        people: CreamMcp.policy_scope(ctx, ws.people).search(q).includes(:company, custom_field_values: :custom_field).limit(10).map { |p| CreamMcp.person_json(p) },
        companies: CreamMcp.policy_scope(ctx, ws.companies).search(q).includes(custom_field_values: :custom_field).limit(10).map { |c| CreamMcp.company_json(c) },
        deals: CreamMcp.policy_scope(ctx, ws.deals).search(q).includes(:company, :contacts, custom_field_values: :custom_field).limit(10).map { |d| CreamMcp.deal_json(d) }
      )
    end
  end

  LIST_PEOPLE = MCP::Tool.define(
    name: "list_people",
    description: "List people in the workspace, optionally filtered by company or free-text query.",
    input_schema: { type: "object",
                   properties: { query: { type: "string" },
                                company_id: { type: "integer" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.people).includes(:company, :owner, custom_field_values: :custom_field).order(:first_name, :last_name)
      scope = scope.search(CreamMcp.arg(args, "query")) if CreamMcp.arg(args, "query").present?
      scope = scope.where(company_id: CreamMcp.arg(args, "company_id")) if CreamMcp.arg(args, "company_id").present?
      CreamMcp.respond_with(people: scope.limit(CreamMcp.list_limit(args)).map { |p| CreamMcp.person_json(p) })
    end
  end

  LIST_COMPANIES = MCP::Tool.define(
    name: "list_companies",
    description: "List companies in the workspace, optionally filtered by industry or free-text query.",
    input_schema: { type: "object",
                   properties: { query: { type: "string" },
                                industry: { type: "string" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.companies).includes(:owner, :people, custom_field_values: :custom_field).order(:name)
      scope = scope.search(CreamMcp.arg(args, "query")) if CreamMcp.arg(args, "query").present?
      scope = scope.where(industry: CreamMcp.arg(args, "industry")) if CreamMcp.arg(args, "industry").present?
      CreamMcp.respond_with(companies: scope.limit(CreamMcp.list_limit(args)).map { |c| CreamMcp.company_json(c) })
    end
  end

  LIST_DEALS = MCP::Tool.define(
    name: "list_deals",
    description: "List deals, optionally filtered by pipeline stage name (e.g. Lead, Won) or free-text query.",
    input_schema: { type: "object",
                   properties: { stage: { type: "string", description: "Pipeline stage name to filter by" },
                                query: { type: "string" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.deals)
        .includes(:company, :contacts, :owner, :pipeline, :pipeline_stage, custom_field_values: :custom_field,
                  deal_products: [ :product, :edition ])
        .order(created_at: :desc)
      scope = scope.search(CreamMcp.arg(args, "query")) if CreamMcp.arg(args, "query").present?
      scope = scope.joins(:pipeline_stage).where("pipeline_stages.name ILIKE ?", CreamMcp.arg(args, "stage")) if CreamMcp.arg(args, "stage").present?
      CreamMcp.respond_with(deals: scope.limit(CreamMcp.list_limit(args)).map { |d| CreamMcp.deal_json(d) })
    end
  end

  GET_RECORD = MCP::Tool.define(
    name: "get_record",
    description: "Get details of a person, company or deal: attributes, recent notes, tasks (up to 20) and activity. " \
                 "For full lists use list_people, list_deals or list_tasks.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      record = CreamMcp.find_record(ws, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :show?)
      base = case record
      when Person then CreamMcp.person_json(record).merge(description: record.description, linkedin_url: record.linkedin_url)
      when Company then CreamMcp.company_json(record).merge(description: record.description,
        people: record.people.limit(10).map { |p| CreamMcp.person_json(p) },
        deals: record.deals.limit(10).map { |d| CreamMcp.deal_json(d) })
      when Deal then CreamMcp.deal_json(record)
      end
      comments = if CreamFeatures.enabled?(:comments)
        record.comments.includes(:user).recent_first.limit(20).map { |c| CreamMcp.comment_json(c) }
      end
      CreamMcp.respond_with(
        base.merge(
          notes: record.notes.includes(:user).order(created_at: :desc).limit(10).map { |n|
            { id: n.id, title: n.title, body: n.body, author: n.user.name, created_at: n.created_at.iso8601 }.compact
          },
          comments: comments,
          tasks: record.tasks.due_order.limit(20).map { |t| CreamMcp.task_json(t) },
          recent_activity: record.activities.includes(:user).recent_first.limit(10).map { |a|
            { action: a.action, by: a.user&.name, at: a.created_at.iso8601, details: a.metadata.presence }.compact
          }
        ).compact
      )
    end
  end

  CREATE_PERSON = MCP::Tool.define(
    name: "create_person",
    description: "Create a person (contact). Provide at least a first or last name.",
    input_schema: { type: "object",
                   properties: { first_name: { type: "string" }, last_name: { type: "string" },
                                email: { type: "string" }, phone: { type: "string" },
                                job_title: { type: "string" }, location: { type: "string" },
                                company_id: { type: "integer", description: "Existing company id (required — a person belongs to a company)" },
                                description: { type: "string" },
                                custom_fields: { type: "object", description: "Workspace-defined custom fields keyed by field key (see list_custom_fields)" } },
                   required: [ "first_name", "company_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      person = ws.people.new(
        CreamMcp.picked(args, "first_name", "last_name", "email", "phone", "job_title", "location", "description")
          .merge(company_id: CreamMcp.arg(args, "company_id"), owner: pundit_ctx.user, workspace: ws)
      )
      person.custom_fields = CreamMcp.arg(args, "custom_fields") if CreamMcp.arg(args, "custom_fields").present?
      CreamMcp.authorize!(pundit_ctx, person, :create?)
      person.save!
      CreamMcp.respond_with(created: CreamMcp.person_json(person))
    end
  end

  CREATE_COMPANY = MCP::Tool.define(
    name: "create_company",
    description: "Create a company.",
    input_schema: { type: "object",
                   properties: { name: { type: "string" }, domain: { type: "string" },
                                industry: { type: "string" },
                                employee_range: { type: "string", enum: Company::EMPLOYEE_RANGES },
                                location: { type: "string" }, annual_revenue: { type: "integer" },
                                description: { type: "string" },
                                fiscal_information: { type: "string",
                                  description: "Razon social, CIF/NIF, direccion fiscal, IBAN (texto libre)" },
                                custom_fields: { type: "object", description: "Workspace-defined custom fields keyed by field key (see list_custom_fields)" } },
                   required: [ "name" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      company = ws.companies.new(
        CreamMcp.picked(args, "name", "domain", "industry", "employee_range", "location", "annual_revenue",
          "description", "fiscal_information")
          .merge(owner: pundit_ctx.user, workspace: ws)
      )
      company.custom_fields = CreamMcp.arg(args, "custom_fields") if CreamMcp.arg(args, "custom_fields").present?
      CreamMcp.authorize!(pundit_ctx, company, :create?)
      company.save!
      CreamMcp.respond_with(created: CreamMcp.company_json(company))
    end
  end

  CREATE_DEAL = MCP::Tool.define(
    name: "create_deal",
    description: "Create a deal. A deal belongs to a company and needs a next action (a task with a future due date). " \
                 "Contacts are optional but, when provided, must belong to the company.",
    input_schema: { type: "object",
                   properties: { name: { type: "string" },
                                company_id: { type: "integer", description: "Company the deal belongs to" },
                                person_ids: { type: "array", items: { type: "integer" },
                                             description: "Optional contact person ids — must belong to the company when provided" },
                                next_action_title: { type: "string", description: "The next action to take on this deal" },
                                next_action_due_on: { type: "string", description: "Due date for the next action, ISO (YYYY-MM-DD), in the future" },
                                value: { type: "number" },
                                currency: { type: "string", enum: %w[EUR USD] },
                                pipeline: { type: "string", description: "Pipeline name (defaults to the workspace default)" },
                                stage: { type: "string", description: "Pipeline stage name (defaults to the first stage)" },
                                probability: { type: "integer", minimum: 0, maximum: 100 },
                                expected_close_date: { type: "string", description: "ISO date (YYYY-MM-DD)" },
                                custom_fields: { type: "object", description: "Workspace-defined custom fields keyed by field key (see list_custom_fields)" } },
                   required: [ "name", "company_id", "next_action_title", "next_action_due_on" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      pipeline_name = CreamMcp.arg(args, "pipeline")
      pipeline = (pipeline_name && ws.pipelines.find_by("name ILIKE ?", pipeline_name)) || Pipeline.default_for(ws)
      stage_name = CreamMcp.arg(args, "stage")
      stage = (stage_name && pipeline&.pipeline_stages&.find_by("name ILIKE ?", stage_name)) || pipeline&.first_stage
      deal = ws.deals.new(
        CreamMcp.picked(args, "name", "value", "currency", "probability", "expected_close_date", "company_id")
          .merge(owner: pundit_ctx.user, workspace: ws, pipeline: pipeline, pipeline_stage: stage)
      )
      deal.contact_ids = Array(CreamMcp.arg(args, "person_ids"))
      deal.tasks.build(title: CreamMcp.arg(args, "next_action_title"), due_on: CreamMcp.arg(args, "next_action_due_on"),
        workspace: ws, user: pundit_ctx.user, assignee: pundit_ctx.user)
      deal.custom_fields = CreamMcp.arg(args, "custom_fields") if CreamMcp.arg(args, "custom_fields").present?
      CreamMcp.authorize!(pundit_ctx, deal, :create?)
      deal.save!
      CreamMcp.respond_with(created: CreamMcp.deal_json(deal))
    end
  end

  UPDATE_PERSON = MCP::Tool.define(
    name: "update_person",
    description: "Update a person's fields. Only the fields provided are changed; pass an empty string to clear one. " \
                 "Use set_custom_fields for custom fields.",
    input_schema: { type: "object",
                   properties: { person_id: { type: "integer" },
                                first_name: { type: "string" }, last_name: { type: "string" },
                                email: { type: "string" }, phone: { type: "string" },
                                job_title: { type: "string" }, location: { type: "string" },
                                linkedin_url: { type: "string" }, description: { type: "string" },
                                company_id: { type: "integer", description: "Move the person to another existing company" } },
                   required: [ "person_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      person = ctx.workspace.people.find(CreamMcp.arg(args, "person_id"))
      CreamMcp.authorize!(ctx, person, :update?)
      person.update!(CreamMcp.picked(args, "first_name", "last_name", "email", "phone",
        "job_title", "location", "linkedin_url", "description", "company_id"))
      CreamMcp.respond_with(updated: CreamMcp.person_json(person))
    end
  end

  UPDATE_COMPANY = MCP::Tool.define(
    name: "update_company",
    description: "Update a company's fields. Only the fields provided are changed; pass an empty string to clear one. " \
                 "Use set_custom_fields for custom fields.",
    input_schema: { type: "object",
                   properties: { company_id: { type: "integer" },
                                name: { type: "string" }, domain: { type: "string" },
                                industry: { type: "string" },
                                employee_range: { type: "string", enum: Company::EMPLOYEE_RANGES },
                                location: { type: "string" }, annual_revenue: { type: "integer" },
                                description: { type: "string" },
                                fiscal_information: { type: "string",
                                  description: "Razon social, CIF/NIF, direccion fiscal, IBAN (texto libre)" } },
                   required: [ "company_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      company = ctx.workspace.companies.find(CreamMcp.arg(args, "company_id"))
      CreamMcp.authorize!(ctx, company, :update?)
      company.update!(CreamMcp.picked(args, "name", "domain", "industry", "employee_range",
        "location", "annual_revenue", "description", "fiscal_information"))
      CreamMcp.respond_with(updated: CreamMcp.company_json(company))
    end
  end

  UPDATE_DEAL = MCP::Tool.define(
    name: "update_deal",
    description: "Update a deal's fields. Only the fields provided are changed. person_ids replaces the deal's " \
                 "contacts (they must belong to the deal's company). pipeline moves the deal to another pipeline " \
                 "(landing on its first stage unless stage is also given); stage moves it within its pipeline — " \
                 "both are logged in the activity timeline. Use set_custom_fields for custom fields.",
    input_schema: { type: "object",
                   properties: { deal_id: { type: "integer" },
                                name: { type: "string" },
                                value: { type: "number", description: "Deal value; note it is recalculated from product line subtotals whenever the deal's line items change" },
                                currency: { type: "string", enum: %w[EUR USD] },
                                probability: { type: "integer", minimum: 0, maximum: 100 },
                                expected_close_date: { type: "string", description: "ISO date (YYYY-MM-DD)" },
                                company_id: { type: "integer", description: "Move the deal to another existing company" },
                                person_ids: { type: "array", items: { type: "integer" },
                                             description: "Replaces the deal's contacts — must belong to the deal's company" },
                                pipeline: { type: "string", description: "Target pipeline name" },
                                stage: { type: "string", description: "Target stage name within the (possibly new) pipeline" } },
                   required: [ "deal_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      ws = ctx.workspace
      deal = ws.deals.find(CreamMcp.arg(args, "deal_id"))
      CreamMcp.authorize!(ctx, deal, :update?)
      attrs = CreamMcp.picked(args, "name", "value", "currency", "probability", "expected_close_date", "company_id")
      deal.contact_ids = Array(CreamMcp.arg(args, "person_ids")) unless CreamMcp.arg(args, "person_ids").nil?
      deal.update!(attrs)
      pipeline_name = CreamMcp.arg(args, "pipeline")
      stage_name = CreamMcp.arg(args, "stage")
      if pipeline_name.present? || stage_name.present?
        CreamMcp.authorize!(ctx, deal, :move?)
        if pipeline_name.present?
          target = ws.pipelines.where("name ILIKE ?", pipeline_name).first
          raise ActiveRecord::RecordNotFound, "Unknown pipeline: #{pipeline_name}" unless target
          deal.move_to_pipeline!(target)
        end
        deal.move_to_stage!(stage_name) if stage_name.present?
      end
      CreamMcp.respond_with(updated: CreamMcp.deal_json(deal.reload))
    end
  end

  UPDATE_DEAL_STAGE = MCP::Tool.define(
    name: "update_deal_stage",
    description: "Move a deal to another stage of its pipeline, by stage name (logged in the activity timeline).",
    input_schema: { type: "object",
                   properties: { deal_id: { type: "integer" },
                                stage: { type: "string", description: "Target stage name within the deal's pipeline" } },
                   required: [ "deal_id", "stage" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      deal = pundit_ctx.workspace.deals.find(CreamMcp.arg(args, "deal_id"))
      CreamMcp.authorize!(pundit_ctx, deal, :move?)
      deal.move_to_stage!(CreamMcp.arg(args, "stage"))
      CreamMcp.respond_with(updated: CreamMcp.deal_json(deal))
    end
  end

  LIST_PERSON_DUPLICATES = MCP::Tool.define(
    name: "list_person_duplicates",
    description: "List groups of people that share the same email address in the workspace. " \
                 "Use this to find merge candidates before calling merge_person.",
    input_schema: { type: "object", properties: {} }
  ) do |server_context:, **_args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      groups = PersonDuplicateGroups.call(ctx.workspace).map do |group|
        {
          email: group.email,
          company: group.company_label,
          people: group.people.map { |person| CreamMcp.person_json(person) }
        }
      end
      CreamMcp.respond_with(duplicate_groups: groups)
    end
  end

  LIST_COMPANY_DUPLICATES = MCP::Tool.define(
    name: "list_company_duplicates",
    description: "List groups of companies that likely represent the same organization " \
                 "(same domain or similar name). Use before calling merge_company.",
    input_schema: { type: "object", properties: {} }
  ) do |server_context:, **_args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      groups = CompanyDuplicateGroups.call(ctx.workspace).map do |group|
        {
          reason: group.reason,
          companies: group.companies.map { |company| CreamMcp.company_json(company) }
        }
      end
      CreamMcp.respond_with(duplicate_groups: groups)
    end
  end

  MERGE_PERSON = MCP::Tool.define(
    name: "merge_person",
    description: "Merge duplicate people into a primary contact. Secondary records are permanently deleted " \
                 "after their notes, tasks, deal links and other data are moved to the primary.",
    input_schema: { type: "object",
                   properties: { primary_id: { type: "integer", description: "The contact to keep" },
                                secondary_ids: { type: "array", items: { type: "integer" },
                                                 description: "Contact ids to merge into the primary (at least one)" } },
                   required: [ "primary_id", "secondary_ids" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      ws = ctx.workspace
      primary = ws.people.find(CreamMcp.arg(args, "primary_id"))
      CreamMcp.authorize!(ctx, primary, :merge?)
      secondary_ids = Array(CreamMcp.arg(args, "secondary_ids")).map(&:to_i).uniq - [ primary.id ]
      secondaries = secondary_ids.filter_map { |id| ws.people.find_by(id: id) }
      if secondaries.size != secondary_ids.size
        missing = secondary_ids - secondaries.map(&:id)
        return CreamMcp.error_response("invalid_argument", "Unknown person ids: #{missing.join(", ")}")
      end
      secondaries.each { |secondary| CreamMcp.authorize!(ctx, secondary, :merge?) }
      PersonMerger.call(primary: primary, secondaries: secondaries, user: ctx.user)
      CreamMcp.respond_with(merged: CreamMcp.person_json(primary.reload), merged_ids: secondary_ids)
    rescue PersonMerger::Error => e
      CreamMcp.error_response("merge_error", e.message)
    end
  end

  MERGE_COMPANY = MCP::Tool.define(
    name: "merge_company",
    description: "Merge duplicate companies into a primary company. Secondary records are permanently deleted " \
                 "after their people, deals, notes and other data are moved to the primary.",
    input_schema: { type: "object",
                   properties: { primary_id: { type: "integer", description: "The company to keep" },
                                secondary_ids: { type: "array", items: { type: "integer" },
                                                 description: "Company ids to merge into the primary (at least one)" } },
                   required: [ "primary_id", "secondary_ids" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      ws = ctx.workspace
      primary = ws.companies.find(CreamMcp.arg(args, "primary_id"))
      CreamMcp.authorize!(ctx, primary, :merge?)
      secondary_ids = Array(CreamMcp.arg(args, "secondary_ids")).map(&:to_i).uniq - [ primary.id ]
      secondaries = secondary_ids.filter_map { |id| ws.companies.find_by(id: id) }
      if secondaries.size != secondary_ids.size
        missing = secondary_ids - secondaries.map(&:id)
        return CreamMcp.error_response("invalid_argument", "Unknown company ids: #{missing.join(", ")}")
      end
      secondaries.each { |secondary| CreamMcp.authorize!(ctx, secondary, :merge?) }
      CompanyMerger.call(primary: primary, secondaries: secondaries, user: ctx.user)
      CreamMcp.respond_with(merged: CreamMcp.company_json(primary.reload), merged_ids: secondary_ids)
    rescue CompanyMerger::Error => e
      CreamMcp.error_response("merge_error", e.message)
    end
  end

  DELETE_RECORD = MCP::Tool.define(
    name: "delete_record",
    description: "Permanently delete a person, company or deal. This cannot be undone. " \
                 "Deleting a company also deletes all of its people and deals.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      record = CreamMcp.find_record(ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(ctx, record, :destroy?)
      deleted = { type: record.class.name.downcase, id: record.id, name: record.display_name }
      record.destroy!
      CreamMcp.respond_with(deleted: deleted)
    end
  end

  ADD_NOTE = MCP::Tool.define(
    name: "add_note",
    description: "Add a note to a person, company or deal.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                title: { type: "string" },
                                body: { type: "string" } },
                   required: [ "record_type", "record_id", "body" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      record = CreamMcp.find_record(ws, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      note = record.notes.new(workspace: ws, user: pundit_ctx.user,
        title: CreamMcp.arg(args, "title"), body: CreamMcp.arg(args, "body"))
      CreamMcp.authorize!(pundit_ctx, note, :create?)
      note.save!
      CreamMcp.respond_with(created: { id: note.id, title: note.title, body: note.body,
                                      record: CreamMcp.record_ref_json(record) })
    end
  end

  ADD_COMMENT = MCP::Tool.define(
    name: "add_comment",
    description: "Add a comment to the internal discussion thread of a person, company or deal. " \
                 "Mention teammates with @Their Name to notify them. " \
                 "Pass parent_comment_id to reply to an existing comment (ids come from get_record).",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                body: { type: "string" },
                                parent_comment_id: { type: "integer", description: "Optional comment id to reply to" } },
                   required: [ "record_type", "record_id", "body" ] }
  ) do |server_context:, **args|
    return CreamMcp.comments_unavailable_response unless CreamFeatures.enabled?(:comments)

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      record = CreamMcp.find_record(ws, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      parent = CreamMcp.arg(args, "parent_comment_id").presence &&
        record.comments.find(CreamMcp.arg(args, "parent_comment_id"))
      comment = record.comments.new(workspace: ws, user: pundit_ctx.user,
        body: CreamMcp.arg(args, "body"), parent: parent)
      CreamMcp.authorize!(pundit_ctx, comment, :create?)
      comment.save!
      if CreamFeatures.enabled?(:webhooks)
        WebhookDispatcher.dispatch(
          workspace: ws,
          event: "comment.created",
          payload: { comment_id: comment.id, record_type: record.class.name, record_id: record.id }
        )
      end
      CreamMcp.respond_with(created: CreamMcp.comment_json(comment).merge(
        record: CreamMcp.record_ref_json(record)
      ))
    end
  end

  CREATE_TASK = MCP::Tool.define(
    name: "create_task",
    description: "Create a task, optionally linked to a person, company or deal.",
    input_schema: { type: "object",
                   properties: { title: { type: "string" },
                                due_on: { type: "string", description: "ISO date (YYYY-MM-DD)" },
                                record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "title" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      taskable = CreamMcp.arg(args, "record_type").present? ? CreamMcp.find_record(ws, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id")) : nil
      task = ws.tasks.new(
        title: CreamMcp.arg(args, "title"), due_on: CreamMcp.arg(args, "due_on"), taskable: taskable,
        user: pundit_ctx.user, assignee: pundit_ctx.user, workspace: ws
      )
      CreamMcp.authorize!(pundit_ctx, task, :create?)
      task.save!
      CreamMcp.respond_with(created: CreamMcp.task_json(task))
    end
  end

  COMPLETE_TASK = MCP::Tool.define(
    name: "complete_task",
    description: "Mark a task as completed (or reopen it if already completed).",
    input_schema: { type: "object",
                   properties: { task_id: { type: "integer" } },
                   required: [ "task_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      task = pundit_ctx.workspace.tasks.find(CreamMcp.arg(args, "task_id"))
      CreamMcp.authorize!(pundit_ctx, task, :toggle?)
      task.toggle_completed!
      CreamMcp.respond_with(task: CreamMcp.task_json(task))
    end
  end

  PIPELINE_SUMMARY = MCP::Tool.define(
    name: "pipeline_summary",
    description: "Pipeline overview: deal count and total value per stage, plus open/won totals.",
    input_schema: { type: "object", properties: {} }
  ) do |server_context:, **_args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      CreamMcp.authorize!(pundit_ctx, ws, :dashboard?)
      deals = CreamMcp.policy_scope(pundit_ctx, ws.deals)
      tasks = CreamMcp.policy_scope(pundit_ctx, ws.tasks)
      counts = deals.group(:pipeline_stage_id).count
      values = deals.group(:pipeline_stage_id).sum(:value)
      stages = ws.pipeline_stages.ordered.to_h do |stage|
        [ stage.name, { count: counts[stage.id] || 0, total_value: (values[stage.id] || 0).to_f,
                      probability: stage.probability } ]
      end
      CreamMcp.respond_with(
        stages: stages,
        open_pipeline_value: deals.open_deals.sum(:value).to_f,
        won_value: deals.won.sum(:value).to_f,
        pending_tasks: tasks.pending.count
      )
    end
  end

  LIST_CUSTOM_FIELDS = MCP::Tool.define(
    name: "list_custom_fields",
    description: "List the workspace's custom field definitions (key, type, options, required) grouped by record type. " \
                 "Use this to know which custom fields can be set on people, companies and deals.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES,
                                                description: "Optional: restrict to one record type" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, ctx.workspace, :search?)
      scope = ctx.workspace.custom_fields.ordered
      type = CreamMcp.arg(args, "record_type")
      scope = scope.where(record_type: type.to_s.capitalize) if type.present?
      grouped = scope.group_by(&:record_type).transform_values do |fields|
        fields.map { |f| CreamMcp.custom_field_definition_json(f) }
      end
      CreamMcp.respond_with(custom_fields: grouped)
    end
  end

  SET_CUSTOM_FIELDS = MCP::Tool.define(
    name: "set_custom_fields",
    description: "Set custom field values on an existing person, company or deal. " \
                 "Pass values keyed by field key (see list_custom_fields). A blank value clears the field.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                custom_fields: { type: "object", description: "Field values keyed by field key" } },
                   required: [ "record_type", "record_id", "custom_fields" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      record = CreamMcp.find_record(ws, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :update?)
      record.custom_fields = CreamMcp.arg(args, "custom_fields")
      record.save!
      json = case record
      when Person then CreamMcp.person_json(record)
      when Company then CreamMcp.company_json(record)
      when Deal then CreamMcp.deal_json(record)
      end
      CreamMcp.respond_with(updated: json)
    end
  end

  LIST_PRODUCTS = MCP::Tool.define(
    name: "list_products",
    description: "List catalogue products, optionally filtered by a free-text query (name or description).",
    input_schema: { type: "object",
                   properties: { query: { type: "string" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, Product, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.products).ordered
      scope = scope.search(CreamMcp.arg(args, "query")) if CreamMcp.arg(args, "query").present?
      CreamMcp.respond_with(products: scope.limit(CreamMcp.list_limit(args)).map { |p| CreamMcp.product_json(p) })
    end
  end

  LIST_TASKS = MCP::Tool.define(
    name: "list_tasks",
    description: "List tasks. Filter by status (pending/completed/overdue), by assignee (mine, assignee_id or " \
                 "assignee_query for any workspace member), or by the person/company/deal they are linked to " \
                 "(record_type with record_id or record_query). For companies and people, also returns open_deal_tasks " \
                 "(tasks on their open deals, grouped by deal).",
    input_schema: { type: "object",
                   properties: { status: { type: "string", enum: %w[pending completed overdue] },
                                mine: { type: "boolean", description: "Only tasks assigned to the current user" },
                                assignee_id: { type: "integer", description: "Tasks assigned to this workspace user id" },
                                assignee_query: { type: "string", description: "Tasks assigned to a workspace user matched by name or email" },
                                record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                record_query: { type: "string", description: "Match the linked record by name (use with record_type)" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, Task, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.tasks).includes(:assignee, :taskable).due_order
      case CreamMcp.arg(args, "status")
      when "pending" then scope = scope.pending
      when "completed" then scope = scope.completed
      when "overdue" then scope = scope.pending.overdue
      end
      if CreamMcp.arg(args, "mine")
        scope = scope.where(assignee: ctx.user)
      elsif CreamMcp.arg(args, "assignee_id").present? || CreamMcp.arg(args, "assignee_query").present?
        assignee = CreamMcp.resolve_assignee(
          ctx.workspace,
          id: CreamMcp.arg(args, "assignee_id"),
          query: CreamMcp.arg(args, "assignee_query")
        )
        scope = scope.where(assignee: assignee)
      end
      if CreamMcp.arg(args, "record_type").present?
        record = CreamMcp.resolve_record_for_tasks(
          ctx.workspace,
          CreamMcp.arg(args, "record_type"),
          id: CreamMcp.arg(args, "record_id"),
          query: CreamMcp.arg(args, "record_query")
        )
        limit = CreamMcp.list_limit(args)
        deals_scope = CreamMcp.policy_scope(ctx, ctx.workspace.deals)
        payload = if record.is_a?(Company) || record.is_a?(Person)
          CreamMcp.record_tasks_payload(scope, record, deals_scope, limit: limit)
        else
          { tasks: scope.where(taskable: record).limit(limit).map { |t| CreamMcp.task_json(t) } }
        end
        CreamMcp.respond_with(payload)
      else
        CreamMcp.respond_with(tasks: scope.limit(CreamMcp.list_limit(args)).map { |t| CreamMcp.task_json(t) })
      end
    rescue ActiveRecord::RecordNotFound, ArgumentError => e
      CreamMcp.error_response("invalid_argument", e.message)
    end
  end

  LIST_MY_TASKS = MCP::Tool.define(
    name: "list_my_tasks",
    description: "List tasks assigned to you. Use for questions like overdue tasks, tasks due today, or both. " \
                 "Returns title and url for each task. Prefer this over list_tasks, natural_language_search or get_record " \
                 "for personal task queries.",
    input_schema: { type: "object",
                   properties: { scope: { type: "string",
                                            enum: %w[today_or_overdue today overdue pending],
                                            description: "Filter: today_or_overdue (default), today, overdue, or all pending" },
                                limit: { type: "integer", description: "Max results (default 50, max 100)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context, tool: "list_my_tasks") do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, Task, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.tasks)
        .pending
        .where(assignee: ctx.user)
        .includes(:assignee, :taskable)
        .due_order
      case CreamMcp.arg(args, "scope").presence || "today_or_overdue"
      when "today" then scope = scope.due_today
      when "overdue" then scope = scope.overdue
      when "pending" then scope = scope
      else scope = scope.due_today_or_overdue
      end
      CreamMcp.respond_with(
        tasks: scope.limit(CreamMcp.list_limit(args, MY_TASKS_DEFAULT_LIMIT)).map { |t| CreamMcp.task_json(t) }
      )
    end
  end

  LIST_EMAILS = MCP::Tool.define(
    name: "list_emails",
    description: "List emails (read-only): most recent first. Filter by the linked person/company/deal, " \
                 "by status (sent/scheduled/opened/failed), or only those awaiting a follow-up.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                status: { type: "string" },
                                awaiting_follow_up: { type: "boolean", description: "Only sent emails with a pending follow-up and no reply yet" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, EmailMessage, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.email_messages).includes(:record).recent_first
      if CreamMcp.arg(args, "record_type").present?
        record = CreamMcp.find_record(ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
        scope = scope.where(record: record)
      end
      scope = scope.where(status: CreamMcp.arg(args, "status")) if CreamMcp.arg(args, "status").present?
      scope = scope.where("follow_up_at IS NOT NULL AND replied_at IS NULL AND status != 'scheduled'") if CreamMcp.arg(args, "awaiting_follow_up")
      CreamMcp.respond_with(emails: scope.limit(CreamMcp.list_limit(args)).map { |e| CreamMcp.email_json(e) })
    end
  end

  GET_EMAIL = MCP::Tool.define(
    name: "get_email",
    description: "Get the full detail of a single email, including its body, direction (inbound/outbound) " \
                 "and any replies linked to it. Email ids come from list_emails.",
    input_schema: { type: "object",
                   properties: { email_id: { type: "integer" } },
                   required: [ "email_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      email = CreamMcp.policy_scope(ctx, ctx.workspace.email_messages).find(CreamMcp.arg(args, "email_id"))
      CreamMcp.authorize!(ctx, email, :show?)
      CreamMcp.respond_with(email: CreamMcp.email_detail_json(email))
    end
  end

  LIST_ACTIVITY = MCP::Tool.define(
    name: "list_activity",
    description: "Workspace activity timeline (most recent first), optionally scoped to a single person, company or deal.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, Activity, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.activities).includes(:user, :subject).recent_first
      if CreamMcp.arg(args, "record_type").present?
        record = CreamMcp.find_record(ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
        scope = scope.where(subject: record)
      end
      CreamMcp.respond_with(activity: scope.limit(CreamMcp.list_limit(args)).map { |a| CreamMcp.activity_json(a) })
    end
  end

  LIST_PAYMENTS = MCP::Tool.define(
    name: "list_payments",
    description: "List Stripe payments imported into the workspace (read-only). " \
                 "Filter by status (pending_review/matched/ignored), free-text (customer/email/description) " \
                 "or the linked deal. Amounts are in the payment currency (not cents).",
    input_schema: { type: "object",
                   properties: { status: { type: "string", enum: StripePayment::STATUSES },
                                query: { type: "string" },
                                deal_id: { type: "integer", description: "Only payments matched to this deal" },
                                limit: { type: "integer", description: "Max results (default 25)" } } }
  ) do |server_context:, **args|
    return CreamMcp.payments_unavailable_response unless CreamFeatures.enabled?(:stripe_payments)

    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, StripePayment, :index?)
      scope = CreamMcp.policy_scope(ctx, ctx.workspace.stripe_payments)
        .includes(:deal, :suggested_deal, :suggested_person).recent_first
      scope = scope.where(status: CreamMcp.arg(args, "status")) if CreamMcp.arg(args, "status").present?
      scope = scope.search(CreamMcp.arg(args, "query")) if CreamMcp.arg(args, "query").present?
      scope = scope.where(deal_id: CreamMcp.arg(args, "deal_id")) if CreamMcp.arg(args, "deal_id").present?
      CreamMcp.respond_with(payments: scope.limit(CreamMcp.list_limit(args)).map { |p| CreamMcp.payment_json(p) })
    end
  end

  LIST_PIPELINES = MCP::Tool.define(
    name: "list_pipelines",
    description: "List the workspace's pipelines and their ordered stages (name, probability, won/closed flags). " \
                 "Use this to discover valid stage names for create_deal and update_deal_stage.",
    input_schema: { type: "object", properties: {} }
  ) do |server_context:, **_args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      CreamMcp.authorize!(ctx, Pipeline, :index?)
      pipelines = CreamMcp.policy_scope(ctx, ctx.workspace.pipelines).ordered.includes(:pipeline_stages)
      CreamMcp.respond_with(pipelines: pipelines.map { |pl| CreamMcp.pipeline_json(pl) })
    end
  end

  CREATE_PRODUCT = MCP::Tool.define(
    name: "create_product",
    description: "Add a product to the catalogue.",
    input_schema: { type: "object",
                   properties: { name: { type: "string" },
                                price: { type: "number" },
                                description: { type: "string" } },
                   required: [ "name" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      product = ctx.workspace.products.new(CreamMcp.picked(args, "name", "price", "description"))
      CreamMcp.authorize!(ctx, product, :create?)
      product.save!
      CreamMcp.respond_with(created: CreamMcp.product_json(product))
    end
  end

  UPDATE_PRODUCT = MCP::Tool.define(
    name: "update_product",
    description: "Update a catalogue product's name, price or description.",
    input_schema: { type: "object",
                   properties: { product_id: { type: "integer" },
                                name: { type: "string" },
                                price: { type: "number" },
                                description: { type: "string" } },
                   required: [ "product_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      product = ctx.workspace.products.find(CreamMcp.arg(args, "product_id"))
      CreamMcp.authorize!(ctx, product, :update?)
      product.update!(CreamMcp.picked(args, "name", "price", "description"))
      CreamMcp.respond_with(updated: CreamMcp.product_json(product))
    end
  end

  ADD_DEAL_PRODUCT = MCP::Tool.define(
    name: "add_deal_product",
    description: "Add a product line item to a deal. The unit price defaults to the catalogue price unless given. " \
                 "An optional edition names a product variant (created in the workspace if new). " \
                 "The deal's value is recalculated automatically from its line subtotals.",
    input_schema: { type: "object",
                   properties: { deal_id: { type: "integer" },
                                product_id: { type: "integer" },
                                quantity: { type: "integer", minimum: 1 },
                                unit_price: { type: "number", description: "Optional override; defaults to the catalogue price" },
                                edition: { type: "string", description: "Optional edition/variant name (created in the workspace if it doesn't exist yet)" } },
                   required: [ "deal_id", "product_id", "quantity" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      deal = ctx.workspace.deals.find(CreamMcp.arg(args, "deal_id"))
      CreamMcp.authorize!(ctx, deal, :update?)
      product = ctx.workspace.products.find(CreamMcp.arg(args, "product_id"))
      line = { product: product, quantity: CreamMcp.arg(args, "quantity") }
        .merge(CreamMcp.picked(args, "unit_price"))
      line[:edition_name] = CreamMcp.arg(args, "edition") if CreamMcp.arg(args, "edition").present?
      deal.deal_products.create!(line)
      CreamMcp.respond_with(updated: CreamMcp.deal_json(deal.reload))
    end
  end

  UPDATE_DEAL_PRODUCT = MCP::Tool.define(
    name: "update_deal_product",
    description: "Update an existing product line item on a deal: its quantity, unit price and/or edition. " \
                 "Pass an empty edition to clear it. The deal's value is recalculated automatically. " \
                 "Line item ids come from get_record on the deal.",
    input_schema: { type: "object",
                   properties: { deal_id: { type: "integer" },
                                line_item_id: { type: "integer", description: "Id of the deal's product line item to update" },
                                quantity: { type: "integer", minimum: 1 },
                                unit_price: { type: "number" },
                                edition: { type: "string", description: "Edition/variant name (created if new); pass an empty string to clear it" } },
                   required: [ "deal_id", "line_item_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      deal = ctx.workspace.deals.find(CreamMcp.arg(args, "deal_id"))
      CreamMcp.authorize!(ctx, deal, :update?)
      line = deal.deal_products.find(CreamMcp.arg(args, "line_item_id"))
      attrs = CreamMcp.picked(args, "quantity", "unit_price")
      attrs[:edition_name] = CreamMcp.arg(args, "edition") unless CreamMcp.arg(args, "edition").nil?
      line.update!(attrs)
      CreamMcp.respond_with(updated: CreamMcp.deal_json(deal.reload))
    end
  end

  UPDATE_TASK = MCP::Tool.define(
    name: "update_task",
    description: "Update a task's title or due date. Use complete_task to toggle completion.",
    input_schema: { type: "object",
                   properties: { task_id: { type: "integer" },
                                title: { type: "string" },
                                due_on: { type: "string", description: "ISO date (YYYY-MM-DD)" } },
                   required: [ "task_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      ctx = CreamMcp.pundit_context(server_context)
      task = ctx.workspace.tasks.find(CreamMcp.arg(args, "task_id"))
      CreamMcp.authorize!(ctx, task, :update?)
      task.update!(CreamMcp.picked(args, "title", "due_on"))
      CreamMcp.respond_with(updated: CreamMcp.task_json(task))
    end
  end

  GET_DEAL_HISTORY = MCP::Tool.define(
    name: "get_deal_history",
    description: "Full audit timeline for a deal: PaperTrail field-change versions plus " \
                 "domain activities (notes, comments, stage/pipeline moves, contacts/products " \
                 "changes, email opens/clicks, task completions), most recent first.",
    input_schema: { type: "object",
                   properties: { deal_id: { type: "integer" },
                                limit: { type: "integer", description: "Max entries (default 50)" } },
                   required: [ "deal_id" ] }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      deal = ws.deals.find(CreamMcp.arg(args, "deal_id"))
      CreamMcp.authorize!(pundit_ctx, deal, :show?)

      limit = CreamMcp.list_limit(args, 50)
      versions = deal.versions.where(workspace_id: [ ws.id, nil ]).order(created_at: :desc, id: :desc).limit(limit)
      activities = deal.activities.includes(:user)
        .where(workspace: ws, action: DealVersionsController::ACTIVITY_ACTIONS)
        .recent_first
        .limit(limit)

      users_by_id = User.where(id: versions.map(&:whodunnit).compact.map(&:to_i)).index_by(&:id)

      timeline = (versions.map { |v| [ v.created_at.to_i, v.id, CreamMcp.deal_version_json(v, users_by_id) ] } +
                  activities.map { |a| [ a.created_at.to_i, a.id, { kind: "activity" }.merge(CreamMcp.activity_json(a)) ] })
        .sort_by { |ts, tie, _| [ -ts, -tie ] }
        .first(limit)
        .map(&:last)

      CreamMcp.respond_with(deal: CreamMcp.deal_json(deal), timeline: timeline)
    end
  end

  RECENT_CHANGES = MCP::Tool.define(
    name: "recent_changes",
    description: "What happened recently in the workspace: new deals, companies and people, " \
                 "inbound emails received, significant changes (stage moves, contacts/products, " \
                 "notes, completed tasks) and headline metrics. Read-only, most recent first.",
    input_schema: { type: "object",
                   properties: { days: { type: "integer", description: "Look-back window in days (default 7)" },
                                limit: { type: "integer", description: "Max items per section (default 20)" },
                                include_metrics: { type: "boolean", description: "Include headline counts (default false)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      CreamMcp.authorize!(pundit_ctx, ws, :dashboard?)

      days = (CreamMcp.arg(args, "days") || 7).to_i
      limit = CreamMcp.list_limit(args, 20)
      since = days.days.ago

      deals_scope = CreamMcp.policy_scope(pundit_ctx, ws.deals)
      companies_scope = CreamMcp.policy_scope(pundit_ctx, ws.companies)
      people_scope = CreamMcp.policy_scope(pundit_ctx, ws.people)
      emails_scope = CreamMcp.policy_scope(pundit_ctx, ws.email_messages)
      activities_scope = CreamMcp.policy_scope(pundit_ctx, ws.activities)

      new_deals = deals_scope
        .where("deals.created_at >= ?", since)
        .includes(:company, :contacts, :owner, :pipeline, :pipeline_stage, custom_field_values: :custom_field)
        .order(created_at: :desc)
        .limit(limit)
      new_companies = companies_scope
        .where("companies.created_at >= ?", since)
        .includes(:owner, :people, custom_field_values: :custom_field)
        .order(created_at: :desc)
        .limit(limit)
      new_people = people_scope
        .where("people.created_at >= ?", since)
        .includes(:company, :owner, custom_field_values: :custom_field)
        .order(created_at: :desc)
        .limit(limit)
      inbound_emails = emails_scope
        .inbound
        .where("email_messages.created_at >= ?", since)
        .includes(:record)
        .recent_first
        .limit(limit)
      significant_activity = activities_scope
        .where("activities.created_at >= ?", since)
        .where(action: SIGNIFICANT_ACTIONS)
        .includes(:user, :subject)
        .recent_first
        .limit(limit)

      won_in_window = deals_scope.won.where("deals.updated_at >= ?", since)

      payload = {
        window_days: days,
        new_deals: new_deals.map { |d| CreamMcp.deal_json(d) },
        new_companies: new_companies.map { |c| CreamMcp.company_json(c) },
        new_people: new_people.map { |p| CreamMcp.person_json(p) },
        inbound_emails: inbound_emails.map { |e| CreamMcp.event_email_json(e) },
        significant_activity: significant_activity.map { |a| CreamMcp.activity_json(a) }
      }
      if CreamMcp.arg(args, "include_metrics")
        payload[:metrics] = {
          deals_created: deals_scope.where("deals.created_at >= ?", since).count,
          companies_created: companies_scope.where("companies.created_at >= ?", since).count,
          people_created: people_scope.where("people.created_at >= ?", since).count,
          inbound_emails: emails_scope.inbound.where("email_messages.created_at >= ?", since).count,
          deals_won_in_window: won_in_window.count,
          won_value_in_window: won_in_window.sum(:value).to_f
        }
      end
      CreamMcp.respond_with(payload)
    end
  end

  SALES_FORECAST = MCP::Tool.define(
    name: "sales_forecast",
    description: "Sales forecast: open pipeline weighted by win probability, grouped by expected " \
                 "close month, plus deals closing soon, overdue (past close date, still open) and won totals.",
    input_schema: { type: "object",
                   properties: { pipeline: { type: "string", description: "Optional pipeline name to filter by" },
                                months: { type: "integer", description: "Forecast horizon in months (default 6)" } } }
  ) do |server_context:, **args|
    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      CreamMcp.authorize!(pundit_ctx, ws, :dashboard?)

      open_scope = CreamMcp.policy_scope(pundit_ctx, ws.deals)
        .open_deals
        .joins(:pipeline_stage)
      pipeline_name = CreamMcp.arg(args, "pipeline")
      if pipeline_name.present?
        open_scope = open_scope.joins(:pipeline).where("pipelines.name ILIKE ?", pipeline_name)
      end

      weighted_sum_sql = "deals.value * COALESCE(deals.probability, pipeline_stages.probability, 0) / 100.0"
      months_count = (CreamMcp.arg(args, "months") || 6).to_i
      today = Date.current
      month_starts = (0...months_count).map { |i| (today + i.months).beginning_of_month }

      by_month = month_starts.map do |month_start|
        month_end = month_start.end_of_month
        month_scope = open_scope.where(expected_close_date: month_start..month_end)
        {
          month: month_start.strftime("%Y-%m"),
          deal_count: month_scope.count,
          total_value: month_scope.sum(:value).to_f,
          weighted_value: month_scope.sum(Arel.sql(weighted_sum_sql)).to_f
        }
      end

      no_date_scope = open_scope.where(expected_close_date: nil)
      if no_date_scope.exists?
        by_month << {
          month: "no_date",
          deal_count: no_date_scope.count,
          total_value: no_date_scope.sum(:value).to_f,
          weighted_value: no_date_scope.sum(Arel.sql(weighted_sum_sql)).to_f
        }
      end

      deal_includes = [ :pipeline, :pipeline_stage, :company, :contacts, :owner,
                        { custom_field_values: :custom_field, deal_products: [ :product, :edition ] } ]
      closing_soon = open_scope.where(expected_close_date: today..(today + 30))
        .includes(deal_includes).limit(25)
      overdue = open_scope.where("deals.expected_close_date < ?", today)
        .includes(deal_includes).limit(25)

      won_scope = CreamMcp.policy_scope(pundit_ctx, ws.deals).won

      CreamMcp.respond_with(
        totals: {
          open_deal_count: open_scope.count,
          open_pipeline_value: open_scope.sum(:value).to_f,
          weighted_pipeline_value: open_scope.sum(Arel.sql(weighted_sum_sql)).to_f
        },
        by_month: by_month,
        closing_soon: closing_soon.map { |d| CreamMcp.deal_json(d) },
        overdue: overdue.map { |d| CreamMcp.deal_json(d) },
        won: {
          won_value_total: won_scope.sum(:value).to_f,
          won_value_this_month: won_scope.where("deals.updated_at >= ?", today.beginning_of_month).sum(:value).to_f
        }
      )
    end
  end

  SUMMARIZE_RECORD = MCP::Tool.define(
    name: "summarize_record",
    description: "Generate an AI summary of a person, company or deal with risks, next steps and missing data.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    return CreamMcp.ai_unavailable_response unless CreamMcp.ai_assistant_enabled?

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      record = CreamMcp.find_record(pundit_ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :show?)
      CreamMcp.respond_with(Ai::RecordSummarizer.new(record: record, user: pundit_ctx.user).call)
    rescue Ai::Client::Error => e
      CreamMcp.respond_with(error: "ai_error", message: e.message)
    end
  end

  SUGGEST_NEXT_STEPS = MCP::Tool.define(
    name: "suggest_next_steps",
    description: "Suggest actionable next steps for a CRM record, including optional task suggestions.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    return CreamMcp.ai_unavailable_response unless CreamMcp.ai_assistant_enabled?

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      record = CreamMcp.find_record(pundit_ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :show?)
      result = Ai::NextStepSuggester.new(record: record, user: pundit_ctx.user).call
      CreamMcp.respond_with(result.merge(
        suggestions: result[:suggestions].map { |item|
          item.merge(due_on: item[:due_on]&.iso8601)
        }
      ))
    rescue Ai::Client::Error => e
      CreamMcp.respond_with(error: "ai_error", message: e.message)
    end
  end

  DRAFT_EMAIL = MCP::Tool.define(
    name: "draft_email",
    description: "Draft a follow-up email for a person, company or deal using CRM context.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" },
                                goal: { type: "string", description: "Optional goal for the email draft" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    return CreamMcp.ai_unavailable_response unless CreamMcp.ai_assistant_enabled?

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      record = CreamMcp.find_record(pundit_ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :show?)
      CreamMcp.respond_with(Ai::EmailDrafter.new(
        record: record,
        user: pundit_ctx.user,
        goal: CreamMcp.arg(args, "goal")
      ).call)
    rescue Ai::Client::Error => e
      CreamMcp.respond_with(error: "ai_error", message: e.message)
    end
  end

  NATURAL_LANGUAGE_SEARCH = MCP::Tool.define(
    name: "natural_language_search",
    description: "Search the CRM using natural-language phrases such as stalled deals, overdue tasks or pending follow up.",
    input_schema: { type: "object",
                   properties: { query: { type: "string" } },
                   required: [ "query" ] }
  ) do |server_context:, **args|
    return CreamMcp.ai_unavailable_response unless CreamFeatures.enabled?(:ai_assistant)

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      ws = pundit_ctx.workspace
      CreamMcp.authorize!(pundit_ctx, ws, :search?)
      result = Ai::NaturalLanguageSearch.new(
        workspace: ws,
        query: CreamMcp.arg(args, "query"),
        user: pundit_ctx.user,
        people_scope: CreamMcp.policy_scope(pundit_ctx, ws.people),
        companies_scope: CreamMcp.policy_scope(pundit_ctx, ws.companies),
        deals_scope: CreamMcp.policy_scope(pundit_ctx, ws.deals),
        tasks_scope: CreamMcp.policy_scope(pundit_ctx, ws.tasks)
      ).call
      CreamMcp.respond_with(
        interpretation: result.interpretation,
        people: result.people.map { |person| CreamMcp.person_json(person) },
        companies: result.companies.map { |company| CreamMcp.company_json(company) },
        deals: result.deals.map { |deal| CreamMcp.deal_json(deal) },
        tasks: result.tasks.map { |task| CreamMcp.task_json(task) },
        open_deal_tasks: result.open_deal_tasks.map { |group|
          {
            deal: CreamMcp.record_ref_json(group[:deal]),
            tasks: group[:tasks].map { |task| CreamMcp.task_json(task) }
          }
        }.presence,
        emails: result.emails.map { |email| CreamMcp.email_json(email) }
      )
    end
  end

  ENRICH_RECORD = MCP::Tool.define(
    name: "enrich_record",
    description: "Suggest missing or improvable field values for a record using existing CRM context only.",
    input_schema: { type: "object",
                   properties: { record_type: { type: "string", enum: RECORD_TYPES },
                                record_id: { type: "integer" } },
                   required: [ "record_type", "record_id" ] }
  ) do |server_context:, **args|
    unless CreamFeatures.enabled?(:ai_enrichment) && CreamMcp.ai_assistant_enabled?
      return CreamMcp.ai_unavailable_response
    end

    CreamMcp.with_authorization(server_context) do
      pundit_ctx = CreamMcp.pundit_context(server_context)
      record = CreamMcp.find_record(pundit_ctx.workspace, CreamMcp.arg(args, "record_type"), CreamMcp.arg(args, "record_id"))
      CreamMcp.authorize!(pundit_ctx, record, :show?)
      CreamMcp.respond_with(Ai::RecordEnricher.new(record: record, user: pundit_ctx.user).call)
    rescue Ai::Client::Error => e
      CreamMcp.respond_with(error: "ai_error", message: e.message)
    end
  end
end
