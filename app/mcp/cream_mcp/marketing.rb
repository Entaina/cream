# MCP tools for the marketing hub (MQL pool, consent, campaigns, segments, journeys, scoring).
module CreamMcp
  module Marketing
    def self.tools
      [
        LIST_MQLS, GET_PERSON_MARKETING, LIST_PRODUCT_INTERESTS,
        LIST_SUBSCRIPTION_TYPES, LIST_CAMPAIGNS, GET_CAMPAIGN,
        LIST_SEGMENTS, GET_SEGMENT, LIST_JOURNEYS, GET_JOURNEY,
        LIST_SCORING_RULES, GET_ATTRIBUTION, LIST_EMAIL_TEMPLATES, LIST_LEAD_FORMS,
        CREATE_PRODUCT_INTEREST, CONVERT_MQL_TO_SQL, SET_SUBSCRIPTION,
        ENROLL_IN_JOURNEY, SEND_CAMPAIGN, CANCEL_CAMPAIGN_SEND
      ]
    end

    def self.mql_json(person)
      CreamMcp.person_json(person).merge(
        marketing_eligible: ::Marketing::MqlEligibility.eligible?(person),
        pending_interests: person.product_interests.select(&:pending?).map { |i| CreamMcp::Marketing.product_interest_json(i) }
      )
    end

    def self.product_interest_json(interest)
      {
        id: interest.id,
        person_id: interest.person_id,
        product_id: interest.product_id,
        product: interest.product&.name,
        status: interest.status,
        source_kind: interest.source_kind,
        description: interest.description,
        occurred_at: interest.occurred_at&.iso8601,
        deal_id: interest.deal_id,
        converted_at: interest.converted_at&.iso8601
      }.compact
    end

    def self.subscription_json(subscription)
      {
        subscription_type_id: subscription.subscription_type_id,
        type: subscription.subscription_type.name,
        slug: subscription.subscription_type.slug,
        status: subscription.status,
        opted_in_at: subscription.opted_in_at&.iso8601,
        opted_out_at: subscription.opted_out_at&.iso8601,
        source: subscription.source
      }.compact
    end

    def self.campaign_json(campaign, detail: false)
      payload = {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        utm_source: campaign.utm_source,
        utm_medium: campaign.utm_medium,
        utm_campaign: campaign.utm_campaign,
        url: CreamMcp.record_url(campaign),
        created_at: campaign.created_at.iso8601,
        updated_at: campaign.updated_at.iso8601
      }
      return payload.compact unless detail

      messages = campaign.email_messages.where(marketing_send: true)
      payload.merge(
        stats: {
          sent: messages.count,
          opened: messages.where.not(opened_at: nil).count,
          clicked: messages.where("clicks_count > 0").count
        },
        sends: campaign.campaign_sends.order(created_at: :desc).limit(20).map { |send| CreamMcp::Marketing.campaign_send_json(send) }
      ).compact
    end

    def self.campaign_send_json(send_record)
      {
        id: send_record.id,
        status: send_record.status,
        segment_id: send_record.segment_id,
        segment: send_record.segment&.name,
        email_template_id: send_record.email_template_id,
        subscription_type_id: send_record.subscription_type_id,
        scheduled_at: send_record.scheduled_at&.iso8601,
        started_at: send_record.started_at&.iso8601,
        completed_at: send_record.completed_at&.iso8601,
        variants: send_record.campaign_variants.map { |v|
          {id: v.id, name: v.name, weight: v.weight, winner: v.winner}
        }.presence
      }.compact
    end

    def self.segment_json(segment, members: nil)
      {
        id: segment.id,
        name: segment.name,
        record_type: segment.record_type,
        description: segment.description,
        shared: segment.shared,
        filters: segment.filters.presence,
        count: segment.resolve.count,
        url: CreamMcp.record_url(segment),
        members: members&.map { |r| CreamMcp.record_ref_json(r) }
      }.compact
    end

    def self.journey_json(journey, detail: false)
      payload = {
        id: journey.id,
        name: journey.name,
        entry_trigger: journey.entry_trigger,
        entry_config: journey.entry_config.presence,
        active: journey.active,
        product_id: journey.product_id,
        stop_on_open_deal: journey.stop_on_open_deal,
        max_reenrollments: journey.max_reenrollments,
        url: CreamMcp.record_url(journey)
      }
      return payload.compact unless detail

      enrollments = journey.enrollments.includes(:person, :current_step).order(enrolled_at: :desc).limit(50)
      payload.merge(
        steps: journey.steps.ordered.map { |step| CreamMcp::Marketing.journey_step_json(step) },
        stats: {
          total: journey.enrollments.count,
          active: journey.enrollments.where(state: "active").count,
          waiting: journey.enrollments.where(state: "waiting").count,
          completed: journey.enrollments.where(state: "completed").count
        },
        enrollments: enrollments.map { |e| CreamMcp::Marketing.journey_enrollment_json(e) }
      ).compact
    end

    def self.journey_step_json(step)
      {
        id: step.id,
        position: step.position,
        step_type: step.step_type,
        active: step.active,
        config: step.config.presence
      }.compact
    end

    def self.journey_enrollment_json(enrollment)
      {
        id: enrollment.id,
        person_id: enrollment.person_id,
        person: enrollment.person.display_name,
        state: enrollment.state,
        current_step_id: enrollment.current_step_id,
        enrolled_at: enrollment.enrolled_at&.iso8601,
        next_run_at: enrollment.next_run_at&.iso8601
      }.compact
    end

    def self.scoring_rule_json(rule)
      {
        id: rule.id,
        name: rule.name,
        event_type: rule.event_type,
        points: rule.points,
        decay_days: rule.decay_days,
        active: rule.active,
        conditions: rule.conditions.presence
      }.compact
    end

    def self.lead_form_json(form)
      {
        id: form.id,
        name: form.name,
        slug: form.slug,
        destination: form.destination,
        active: form.active
      }.compact
    end

    def self.email_template_json(template)
      {id: template.id, name: template.name, shared: template.shared}.compact
    end

    def self.subscription_type_json(type)
      {id: type.id, name: type.name, slug: type.slug, active: type.active}.compact
    end

    def self.mql_filters_from_args(args)
      filters = CreamMcp.picked(
        args,
        "q", "subscription_type_id", "subscription_status", "open_deal", "open_deal_product_id",
        "interest_product_id", "interest_status", "dealt_product_id", "lead_form_id",
        "capture_destination", "submitted_from", "submitted_to", "lead_score_min", "lead_score_max"
      ).stringify_keys

      filters["marketing_eligible"] = true
      view = CreamMcp.arg(args, "view")
      filters["open_deal"] = filters["open_deal"].presence || ((view == "no_open_deal") ? "no" : "any")
      product_id = CreamMcp.arg(args, "product_id")
      filters["open_deal_product_id"] = product_id if product_id.present?
      filters
    end

    LIST_MQLS = MCP::Tool.define(
      name: "list_mqls",
      description: "List marketing-eligible contacts (MQL pool) with optional filters matching the MQL admin screen.",
      input_schema: {
        type: "object",
        properties: {
          q: {type: "string", description: "Search name or email"},
          subscription_type_id: {type: "integer"},
          subscription_status: {type: "string", enum: %w[subscribed unsubscribed pending missing]},
          open_deal: {type: "string", enum: %w[any yes no]},
          open_deal_product_id: {type: "integer"},
          interest_product_id: {type: "integer"},
          interest_status: {type: "string", enum: ::Marketing::ProductInterest::STATUSES},
          lead_form_id: {type: "integer"},
          capture_destination: {type: "string", enum: %w[any mql deal]},
          lead_score_min: {type: "integer"},
          lead_score_max: {type: "integer"},
          view: {type: "string", enum: %w[no_open_deal], description: "Shortcut: exclude contacts with any open deal"},
          product_id: {type: "integer", description: "With view=no_open_deal, exclude open deals for this product only"},
          limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}
        }
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:mql_pool) unless CreamFeatures.enabled?(:mql_pool)

      CreamMcp.with_authorization(server_context, tool: "list_mqls") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, :mql, :index?)

        filters = CreamMcp::Marketing.mql_filters_from_args(args)
        base = ::Marketing::MqlEligibility.scope(
          workspace: ws,
          subscription_type_id: filters["subscription_type_id"]
        )
        scope = ::Marketing::FilterResolver.new(
          workspace: ws,
          record_type: "Person",
          filters: filters,
          deal_scope: CreamMcp.policy_scope(pundit_ctx, ws.deals)
        ).resolve(
          base.includes(:company, :product_interests, email_subscriptions: :subscription_type)
        )
        limit = CreamMcp.list_limit(args)
        people = scope.order(lead_score: :desc, updated_at: :desc).limit(limit)
        CreamMcp.respond_with(mqls: people.map { |p| CreamMcp::Marketing.mql_json(p) })
      end
    end

    GET_PERSON_MARKETING = MCP::Tool.define(
      name: "get_person_marketing",
      description: "Marketing context for a person: subscriptions, suppression, interests, journeys, email activity and form submissions.",
      input_schema: {
        type: "object",
        properties: {
          person_id: {type: "integer"},
          person_query: {type: "string", description: "Search by name or email if person_id omitted"}
        }
      }
    ) do |server_context:, **args|
      CreamMcp.with_authorization(server_context, tool: "get_person_marketing") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        person = CreamMcp::Marketing.resolve_person!(ws, pundit_ctx, args)
        CreamMcp.authorize!(pundit_ctx, person, :show?)

        subscriptions = person.email_subscriptions.includes(:subscription_type).map { |s| CreamMcp::Marketing.subscription_json(s) }
        interests = person.product_interests.includes(:product).ordered.map { |i| CreamMcp::Marketing.product_interest_json(i) }
        enrollments = person.journey_enrollments.includes(:journey, :current_step)
          .where(state: %w[active waiting]).order(enrolled_at: :desc).map { |e|
            CreamMcp::Marketing.journey_enrollment_json(e).merge(journey: e.journey.name)
          }
        email_messages = person.email_messages.includes(:email_events).recent_first.limit(20)
        recent_email_events = email_messages.flat_map { |msg|
          msg.email_events.order(occurred_at: :desc).limit(5).map { |ev|
            {
              event_type: ev.event_type,
              occurred_at: ev.occurred_at.iso8601,
              email_message_id: msg.id,
              subject: msg.subject
            }
          }
        }.first(20)
        lead_submissions = person.lead_submissions.includes(:lead_form).order(created_at: :desc).limit(20).map { |sub|
          {
            id: sub.id,
            lead_form_id: sub.lead_form_id,
            form: sub.lead_form&.name,
            capture_destination: sub.capture_destination,
            created_at: sub.created_at.iso8601
          }.compact
        }

        CreamMcp.respond_with(
          person_id: person.id,
          name: person.display_name,
          lifecycle_stage: person.lifecycle_stage,
          lead_score: person.lead_score,
          marketing_eligible: ::Marketing::MqlEligibility.eligible?(person),
          email_suppressed: EmailSuppression.suppressed?(ws, person.email),
          subscriptions: subscriptions.presence,
          product_interests: interests.presence,
          journey_enrollments: enrollments.presence,
          recent_email_events: recent_email_events.presence,
          lead_submissions: lead_submissions.presence
        )
      end
    end

    LIST_PRODUCT_INTERESTS = MCP::Tool.define(
      name: "list_product_interests",
      description: "List product interests for a person, optionally filtered by status.",
      input_schema: {
        type: "object",
        properties: {
          person_id: {type: "integer"},
          status: {type: "string", enum: ::Marketing::ProductInterest::STATUSES}
        },
        required: ["person_id"]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:mql_pool) unless CreamFeatures.enabled?(:mql_pool)

      CreamMcp.with_authorization(server_context, tool: "list_product_interests") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        person = CreamMcp.policy_scope(pundit_ctx, ws.people).find(CreamMcp.arg(args, "person_id"))
        CreamMcp.authorize!(pundit_ctx, person, :show?)

        scope = person.product_interests.includes(:product).ordered
        status = CreamMcp.arg(args, "status")
        scope = scope.where(status: status) if status.present?
        CreamMcp.respond_with(interests: scope.map { |i| CreamMcp::Marketing.product_interest_json(i) })
      end
    end

    LIST_SUBSCRIPTION_TYPES = MCP::Tool.define(
      name: "list_subscription_types",
      description: "List active subscription types (consent lists) in the workspace.",
      input_schema: {type: "object", properties: {}}
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_consent) unless CreamFeatures.enabled?(:marketing_consent)

      CreamMcp.with_authorization(server_context, tool: "list_subscription_types") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, SubscriptionType.new(workspace: ws), :index?)
        SubscriptionType.ensure_defaults!(ws)
        types = CreamMcp.policy_scope(pundit_ctx, ws.subscription_types).active.order(:name)
        CreamMcp.respond_with(subscription_types: types.map { |t| CreamMcp::Marketing.subscription_type_json(t) })
      end
    end

    LIST_CAMPAIGNS = MCP::Tool.define(
      name: "list_campaigns",
      description: "List marketing campaigns in the workspace.",
      input_schema: {
        type: "object",
        properties: {limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}}
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_campaigns) unless CreamFeatures.enabled?(:marketing_campaigns)

      CreamMcp.with_authorization(server_context, tool: "list_campaigns") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, Campaign.new(workspace: ws), :index?)
        campaigns = CreamMcp.policy_scope(pundit_ctx, ws.campaigns).ordered.limit(CreamMcp.list_limit(args))
        CreamMcp.respond_with(campaigns: campaigns.map { |c| CreamMcp::Marketing.campaign_json(c) })
      end
    end

    GET_CAMPAIGN = MCP::Tool.define(
      name: "get_campaign",
      description: "Campaign detail with send history and engagement stats.",
      input_schema: {
        type: "object",
        properties: {campaign_id: {type: "integer"}},
        required: ["campaign_id"]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_campaigns) unless CreamFeatures.enabled?(:marketing_campaigns)

      CreamMcp.with_authorization(server_context, tool: "get_campaign") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        campaign = CreamMcp.policy_scope(pundit_ctx, ws.campaigns).find(CreamMcp.arg(args, "campaign_id"))
        CreamMcp.authorize!(pundit_ctx, campaign, :show?)
        CreamMcp.respond_with(campaign: CreamMcp::Marketing.campaign_json(campaign, detail: true))
      end
    end

    LIST_SEGMENTS = MCP::Tool.define(
      name: "list_segments",
      description: "List marketing segments with member counts.",
      input_schema: {
        type: "object",
        properties: {limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}}
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_segments) unless CreamFeatures.enabled?(:marketing_segments)

      CreamMcp.with_authorization(server_context, tool: "list_segments") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, Segment.new(workspace: ws), :index?)
        segments = CreamMcp.policy_scope(pundit_ctx, ws.segments).ordered.limit(CreamMcp.list_limit(args))
        CreamMcp.respond_with(segments: segments.map { |s| CreamMcp::Marketing.segment_json(s) })
      end
    end

    GET_SEGMENT = MCP::Tool.define(
      name: "get_segment",
      description: "Segment detail with filters, count and optional member preview.",
      input_schema: {
        type: "object",
        properties: {
          segment_id: {type: "integer"},
          include_members: {type: "boolean", description: "Include up to 25 matching records"}
        },
        required: ["segment_id"]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_segments) unless CreamFeatures.enabled?(:marketing_segments)

      CreamMcp.with_authorization(server_context, tool: "get_segment") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        segment = CreamMcp.policy_scope(pundit_ctx, ws.segments).find(CreamMcp.arg(args, "segment_id"))
        CreamMcp.authorize!(pundit_ctx, segment, :show?)

        members = nil
        if CreamMcp.arg(args, "include_members")
          base = (segment.record_type == "Person") ? ws.people : ws.public_send(segment.record_type.tableize)
          members = segment.resolve(base.includes(:company)).limit(25).to_a
        end
        CreamMcp.respond_with(segment: CreamMcp::Marketing.segment_json(segment, members: members))
      end
    end

    LIST_JOURNEYS = MCP::Tool.define(
      name: "list_journeys",
      description: "List marketing journeys (automated sequences).",
      input_schema: {
        type: "object",
        properties: {limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}}
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:journeys) unless CreamFeatures.enabled?(:journeys)

      CreamMcp.with_authorization(server_context, tool: "list_journeys") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, Journey.new(workspace: ws), :index?)
        journeys = CreamMcp.policy_scope(pundit_ctx, ws.journeys).ordered.limit(CreamMcp.list_limit(args))
        CreamMcp.respond_with(journeys: journeys.map { |j| CreamMcp::Marketing.journey_json(j) })
      end
    end

    GET_JOURNEY = MCP::Tool.define(
      name: "get_journey",
      description: "Journey detail with steps, enrollment stats and recent enrollments.",
      input_schema: {
        type: "object",
        properties: {journey_id: {type: "integer"}},
        required: ["journey_id"]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:journeys) unless CreamFeatures.enabled?(:journeys)

      CreamMcp.with_authorization(server_context, tool: "get_journey") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        journey = CreamMcp.policy_scope(pundit_ctx, ws.journeys).find(CreamMcp.arg(args, "journey_id"))
        CreamMcp.authorize!(pundit_ctx, journey, :show?)
        CreamMcp.respond_with(journey: CreamMcp::Marketing.journey_json(journey, detail: true))
      end
    end

    LIST_SCORING_RULES = MCP::Tool.define(
      name: "list_scoring_rules",
      description: "List lead scoring rules (read-only).",
      input_schema: {type: "object", properties: {}}
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:lead_scoring) unless CreamFeatures.enabled?(:lead_scoring)

      CreamMcp.with_authorization(server_context, tool: "list_scoring_rules") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, ScoringRule.new(workspace: ws), :index?)
        rules = CreamMcp.policy_scope(pundit_ctx, ws.scoring_rules).ordered
        CreamMcp.respond_with(scoring_rules: rules.map { |r| CreamMcp::Marketing.scoring_rule_json(r) })
      end
    end

    GET_ATTRIBUTION = MCP::Tool.define(
      name: "get_attribution",
      description: "UTM attribution report (visits, leads, MQLs, deals, revenue).",
      input_schema: {
        type: "object",
        properties: {
          date_range: {type: "string", enum: %w[month quarter year all], description: "Default: month"},
          utm_source: {type: "string"},
          utm_medium: {type: "string"},
          utm_campaign: {type: "string"}
        }
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_attribution) unless CreamFeatures.enabled?(:marketing_attribution)

      CreamMcp.with_authorization(server_context, tool: "get_attribution") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, Campaign.new(workspace: ws), :index?)

        report = ::Marketing::AttributionReport.new(
          workspace: ws,
          utm_source: CreamMcp.arg(args, "utm_source"),
          utm_medium: CreamMcp.arg(args, "utm_medium"),
          utm_campaign: CreamMcp.arg(args, "utm_campaign"),
          date_range: CreamMcp.arg(args, "date_range").presence || "month"
        )
        CreamMcp.respond_with(
          rows: report.rows.map { |row|
            {
              key: row.key,
              label: row.label,
              visits: row.visits,
              leads: row.leads,
              mqls: row.mqls,
              deals: row.deals,
              revenue: row.revenue.to_f
            }
          },
          totals: {
            visits: report.totals.visits,
            leads: report.totals.leads,
            mqls: report.totals.mqls,
            deals: report.totals.deals,
            revenue: report.totals.revenue.to_f
          }
        )
      end
    end

    LIST_EMAIL_TEMPLATES = MCP::Tool.define(
      name: "list_email_templates",
      description: "List email templates available for campaign sends.",
      input_schema: {
        type: "object",
        properties: {limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}}
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:email_templates) unless CreamFeatures.enabled?(:email_templates)

      CreamMcp.with_authorization(server_context, tool: "list_email_templates") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, EmailTemplate.new(workspace: ws, user: pundit_ctx.user), :index?)
        templates = CreamMcp.policy_scope(pundit_ctx, ws.email_templates).visible_to(pundit_ctx.user).ordered
          .limit(CreamMcp.list_limit(args))
        CreamMcp.respond_with(email_templates: templates.map { |t| CreamMcp::Marketing.email_template_json(t) })
      end
    end

    LIST_LEAD_FORMS = MCP::Tool.define(
      name: "list_lead_forms",
      description: "List lead capture forms (MQL or deal destination).",
      input_schema: {
        type: "object",
        properties: {limit: {type: "integer", minimum: 1, maximum: CreamMcp::MAX_LIST_LIMIT}}
      }
    ) do |server_context:, **args|
      CreamMcp.with_authorization(server_context, tool: "list_lead_forms") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        CreamMcp.authorize!(pundit_ctx, LeadForm.new(workspace: ws), :index?)
        forms = CreamMcp.policy_scope(pundit_ctx, ws.lead_forms).ordered.limit(CreamMcp.list_limit(args))
        CreamMcp.respond_with(lead_forms: forms.map { |f| CreamMcp::Marketing.lead_form_json(f) })
      end
    end

    CREATE_PRODUCT_INTEREST = MCP::Tool.define(
      name: "create_product_interest",
      description: "Register manual product interest for an MQL before SQL conversion.",
      input_schema: {
        type: "object",
        properties: {
          person_id: {type: "integer"},
          product_id: {type: "integer"},
          description: {type: "string"}
        },
        required: %w[person_id product_id description]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:mql_pool) unless CreamFeatures.enabled?(:mql_pool)

      CreamMcp.with_authorization(server_context, tool: "create_product_interest") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        person = CreamMcp.policy_scope(pundit_ctx, ws.people).find(CreamMcp.arg(args, "person_id"))
        product = ws.products.find(CreamMcp.arg(args, "product_id"))

        interest = person.product_interests.build(
          workspace: ws,
          product: product,
          description: CreamMcp.arg(args, "description"),
          recorded_by: pundit_ctx.user,
          source_kind: "manual",
          occurred_at: Time.current,
          status: "pending"
        )
        CreamMcp.authorize!(pundit_ctx, interest, :create?, policy_class: ::Marketing::ProductInterestPolicy)

        interest.save!
        ::Marketing::SegmentWatcher.sync_person!(person)
        CreamMcp.respond_with(created: CreamMcp::Marketing.product_interest_json(interest))
      end
    end

    CONVERT_MQL_TO_SQL = MCP::Tool.define(
      name: "convert_mql_to_sql",
      description: "Convert a pending product interest into an SQL opportunity (deal). Requires pipeline and next task.",
      input_schema: {
        type: "object",
        properties: {
          product_interest_id: {type: "integer"},
          pipeline_id: {type: "integer"},
          task_title: {type: "string"},
          task_due_on: {type: "string", description: "ISO date YYYY-MM-DD"},
          name: {type: "string", description: "Deal name (optional)"},
          owner_id: {type: "integer"},
          task_assignee_id: {type: "integer"},
          deal_id: {type: "integer", description: "Link to existing open deal when multiple exist"}
        },
        required: %w[product_interest_id pipeline_id task_title task_due_on]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:mql_pool) unless CreamFeatures.enabled?(:mql_pool)

      CreamMcp.with_authorization(server_context, tool: "convert_mql_to_sql") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        interest = ::Marketing::ProductInterest.where(workspace: ws).find(CreamMcp.arg(args, "product_interest_id"))
        CreamMcp.authorize!(pundit_ctx, interest, :convert?, policy_class: ::Marketing::ProductInterestPolicy)

        attributes = CreamMcp.picked(
          args, "pipeline_id", "task_title", "task_due_on", "name", "owner_id", "task_assignee_id", "deal_id"
        )
        result = ::Marketing::MqlToSqlConverter.call(
          interest: interest,
          actor: pundit_ctx.user,
          attributes: attributes
        )

        payload = {
          status: result.status,
          message: result.message,
          interest: CreamMcp::Marketing.product_interest_json(result.interest)
        }
        payload[:deal] = CreamMcp.deal_json(result.deal) if result.deal
        CreamMcp.respond_with(payload)
      end
    end

    SET_SUBSCRIPTION = MCP::Tool.define(
      name: "set_subscription",
      description: "Subscribe or unsubscribe a person from a subscription type (consent list).",
      input_schema: {
        type: "object",
        properties: {
          person_id: {type: "integer"},
          subscription_type_id: {type: "integer"},
          action: {type: "string", enum: %w[subscribe unsubscribe]}
        },
        required: %w[person_id subscription_type_id action]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_consent) unless CreamFeatures.enabled?(:marketing_consent)

      CreamMcp.with_authorization(server_context, tool: "set_subscription") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        person = CreamMcp.policy_scope(pundit_ctx, ws.people).find(CreamMcp.arg(args, "person_id"))
        CreamMcp.authorize!(pundit_ctx, person, :update?)
        type = ws.subscription_types.find(CreamMcp.arg(args, "subscription_type_id"))

        case CreamMcp.arg(args, "action")
        when "subscribe"
          subscription = ::Marketing::ConsentService.subscribe!(
            person: person,
            subscription_type: type,
            source: "mcp",
            legal_basis: "consent"
          )
        when "unsubscribe"
          ::Marketing::ConsentService.unsubscribe!(
            person: person,
            subscription_type: type,
            source: "mcp"
          )
          subscription = EmailSubscription.find_by(person: person, subscription_type: type)
        else
          return CreamMcp.error_response("invalid_action", "action must be subscribe or unsubscribe")
        end

        CreamMcp.respond_with(
          subscription: subscription && CreamMcp::Marketing.subscription_json(subscription),
          action: CreamMcp.arg(args, "action")
        )
      end
    end

    ENROLL_IN_JOURNEY = MCP::Tool.define(
      name: "enroll_in_journey",
      description: "Manually enroll a person in a marketing journey.",
      input_schema: {
        type: "object",
        properties: {
          journey_id: {type: "integer"},
          person_id: {type: "integer"}
        },
        required: %w[journey_id person_id]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:journeys) unless CreamFeatures.enabled?(:journeys)

      CreamMcp.with_authorization(server_context, tool: "enroll_in_journey") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        journey = CreamMcp.policy_scope(pundit_ctx, ws.journeys).find(CreamMcp.arg(args, "journey_id"))
        person = CreamMcp.policy_scope(pundit_ctx, ws.people).find(CreamMcp.arg(args, "person_id"))
        CreamMcp.authorize!(pundit_ctx, journey, :update?)

        outcome = ::Marketing::JourneyTrigger.enroll!(journey: journey, person: person)
        CreamMcp.respond_with(outcome: outcome.to_s)
      end
    end

    SEND_CAMPAIGN = MCP::Tool.define(
      name: "send_campaign",
      description: "Queue a campaign send to a person segment. Does not deliver immediately; enqueues CampaignSendJob.",
      input_schema: {
        type: "object",
        properties: {
          campaign_id: {type: "integer"},
          segment_id: {type: "integer", description: "Must be a Person segment"},
          email_template_id: {type: "integer", description: "Optional when the campaign already has email content"},
          subscription_type_id: {type: "integer", description: "Defaults to newsletter type"},
          scheduled_at: {type: "string", description: "ISO8601 datetime to schedule the send"}
        },
        required: %w[campaign_id segment_id]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_campaigns) unless CreamFeatures.enabled?(:marketing_campaigns)

      CreamMcp.with_authorization(server_context, tool: "send_campaign") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        campaign = CreamMcp.policy_scope(pundit_ctx, ws.campaigns).find(CreamMcp.arg(args, "campaign_id"))
        CreamMcp.authorize!(pundit_ctx, campaign, :send_campaign?)

        segment = CreamMcp.policy_scope(pundit_ctx, ws.segments).find(CreamMcp.arg(args, "segment_id"))
        unless segment.record_type == "Person"
          return CreamMcp.error_response("invalid_segment", "Segment must be of type Person")
        end

        unless campaign.email_content_present?
          return CreamMcp.error_response("missing_email_content", "Campaign has no email content configured")
        end

        template_id = CreamMcp.arg(args, "email_template_id")
        template = if template_id.present?
          CreamMcp.policy_scope(pundit_ctx, ws.email_templates).find(template_id)
        else
          campaign.email_template
        end
        subscription_type = CreamMcp::Marketing.resolve_subscription_type(ws, CreamMcp.arg(args, "subscription_type_id"))
        scheduled_at = CreamMcp::Marketing.parse_scheduled_at(CreamMcp.arg(args, "scheduled_at"))

        send_record = ws.campaign_sends.create!(
          campaign: campaign,
          segment: segment,
          email_template: template,
          user: pundit_ctx.user,
          subscription_type: subscription_type,
          status: "pending",
          scheduled_at: scheduled_at
        )

        if scheduled_at.present? && scheduled_at > Time.current
          send_record.mark_scheduled!
          campaign.update!(status: "scheduled")
          CampaignSendJob.set(wait_until: scheduled_at).perform_later(send_record.id)
        else
          CampaignSendJob.perform_later(send_record.id)
        end

        CreamMcp.respond_with(
          campaign_send: CreamMcp::Marketing.campaign_send_json(send_record),
          queued: true
        )
      end
    end

    CANCEL_CAMPAIGN_SEND = MCP::Tool.define(
      name: "cancel_campaign_send",
      description: "Cancel a pending or scheduled campaign send.",
      input_schema: {
        type: "object",
        properties: {
          campaign_id: {type: "integer"},
          send_id: {type: "integer"}
        },
        required: %w[campaign_id send_id]
      }
    ) do |server_context:, **args|
      return CreamMcp.feature_unavailable_response(:marketing_campaigns) unless CreamFeatures.enabled?(:marketing_campaigns)

      CreamMcp.with_authorization(server_context, tool: "cancel_campaign_send") do
        pundit_ctx = CreamMcp.pundit_context(server_context)
        ws = pundit_ctx.workspace
        campaign = CreamMcp.policy_scope(pundit_ctx, ws.campaigns).find(CreamMcp.arg(args, "campaign_id"))
        CreamMcp.authorize!(pundit_ctx, campaign, :update?)
        send_record = campaign.campaign_sends.find(CreamMcp.arg(args, "send_id"))
        send_record.cancel!
        CreamMcp.respond_with(campaign_send: CreamMcp::Marketing.campaign_send_json(send_record.reload), cancelled: true)
      end
    end

    def self.resolve_person!(workspace, pundit_ctx, args)
      person_id = CreamMcp.arg(args, "person_id")
      if person_id.present?
        CreamMcp.policy_scope(pundit_ctx, workspace.people).find(person_id)
      else
        query = CreamMcp.arg(args, "person_query")
        raise ActiveRecord::RecordNotFound, "person_id or person_query is required" if query.blank?

        CreamMcp.resolve_record_for_tasks(workspace, "person", query: query)
      end
    end

    def self.resolve_subscription_type(workspace, subscription_type_id)
      SubscriptionType.ensure_defaults!(workspace)
      if subscription_type_id.present?
        workspace.subscription_types.find(subscription_type_id)
      else
        workspace.subscription_types.find_by(slug: "newsletter") ||
          workspace.subscription_types.active.order(:id).first
      end
    end

    def self.parse_scheduled_at(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    end
  end
end
