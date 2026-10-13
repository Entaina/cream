module Marketing
  class ApiPresenter
    MAX_LIST_LIMIT = 100
    DEFAULT_LIST_LIMIT = 25

    def self.list_limit(value, default = DEFAULT_LIST_LIMIT)
      (value.nil? ? default : value.to_i).clamp(1, MAX_LIST_LIMIT)
    end

    def self.mql_filters_from_params(params)
      filters = params.permit(
        :q, :subscription_type_id, :subscription_status, :open_deal, :open_deal_product_id,
        :interest_product_id, :interest_status, :dealt_product_id, :lead_form_id,
        :capture_destination, :submitted_from, :submitted_to, :lead_score_min, :lead_score_max,
        :view, :product_id
      ).to_h.stringify_keys

      filters["marketing_eligible"] = true
      filters["open_deal"] = filters["open_deal"].presence || ((params[:view] == "no_open_deal") ? "no" : "any")
      filters["open_deal_product_id"] = params[:product_id] if params[:product_id].present?
      filters
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

    def self.record_url(record)
      path = record_path_for(record)
      return nil unless path

      base = ENV["CREAM_APP_URL"].presence
      base ? "#{base.chomp("/")}#{path}" : path
    end

    def self.record_path_for(record)
      helpers = Rails.application.routes.url_helpers
      case record
      when Person then helpers.person_path(record)
      when Campaign then helpers.campaign_path(record)
      when Segment then helpers.segment_path(record)
      when Journey then helpers.journey_path(record)
      when Deal then helpers.deal_path(record)
      end
    end

    def self.person_ref_json(record)
      {type: record.class.name.downcase, id: record.id, name: record.display_name, url: record_url(record)}.compact
    end

    def self.mql_json(person)
      {
        id: person.id,
        name: person.display_name,
        email: person.email,
        company_id: person.company_id,
        company: person.company&.name,
        lifecycle_stage: person.lifecycle_stage,
        lead_score: person.lead_score,
        url: record_url(person),
        marketing_eligible: MqlEligibility.eligible?(person),
        pending_interests: person.product_interests.select(&:pending?).map { |i| product_interest_json(i) }
      }.compact
    end

    def self.mql_creation_json(result)
      mql_json(result.person).merge(
        created: result.created,
        internal_notes: result.person.internal_notes,
        subscriptions: result.subscriptions.map { |subscription| subscription_json(subscription) },
        product_interest: result.interest && product_interest_json(result.interest),
        notes: result.notes.map { |note| {id: note.id, title: note.title, body: note.body} },
        attachments: result.attachments.map { |attachment| Api::RecordAttachmentBuilder.json(attachment) },
        sent_email: result.email_message && Api::DealEmailCreator.json(result.email_message)
      ).compact
    end

    def self.person_marketing_json(person, workspace)
      subscriptions = person.email_subscriptions.includes(:subscription_type).map { |s| subscription_json(s) }
      interests = person.product_interests.includes(:product).ordered.map { |i| product_interest_json(i) }
      enrollments = person.journey_enrollments.includes(:journey, :current_step)
        .where(state: %w[active waiting]).order(enrolled_at: :desc).map { |e|
          journey_enrollment_json(e).merge(journey: e.journey.name)
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

      {
        person_id: person.id,
        name: person.display_name,
        lifecycle_stage: person.lifecycle_stage,
        lead_score: person.lead_score,
        marketing_eligible: MqlEligibility.eligible?(person),
        email_suppressed: EmailSuppression.suppressed?(workspace, person.email),
        subscriptions: subscriptions.presence,
        product_interests: interests.presence,
        journey_enrollments: enrollments.presence,
        recent_email_events: recent_email_events.presence,
        lead_submissions: lead_submissions.presence
      }.compact
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
        source: subscription.source,
        consent_evidence: subscription.consent_evidence.presence
      }.compact
    end

    def self.subscription_listing_json(subscription)
      person = subscription.person
      subscription_json(subscription).merge(
        id: subscription.id,
        person: {id: person.id, name: person.display_name, email: person.email, url: record_url(person)}.compact
      )
    end

    def self.campaign_json(campaign, detail: false)
      payload = {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        utm_source: campaign.utm_source,
        utm_medium: campaign.utm_medium,
        utm_campaign: campaign.utm_campaign,
        url: record_url(campaign),
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
        sends: campaign.campaign_sends.order(created_at: :desc).limit(20).map { |send| campaign_send_json(send) }
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
        url: record_url(segment),
        members: members&.map { |r| person_ref_json(r) }
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
        url: record_url(journey)
      }
      return payload.compact unless detail

      enrollments = journey.enrollments.includes(:person, :current_step).order(enrolled_at: :desc).limit(50)
      payload.merge(
        steps: journey.steps.ordered.map { |step| journey_step_json(step) },
        stats: {
          total: journey.enrollments.count,
          active: journey.enrollments.where(state: "active").count,
          waiting: journey.enrollments.where(state: "waiting").count,
          completed: journey.enrollments.where(state: "completed").count
        },
        enrollments: enrollments.map { |e| journey_enrollment_json(e) }
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

    def self.deal_json(deal)
      {
        id: deal.id,
        name: deal.name,
        stage: deal.stage_label,
        value: deal.value.to_f,
        currency: deal.currency,
        company_id: deal.company_id,
        contact_ids: deal.contact_ids,
        url: record_url(deal),
        created_at: deal.created_at.iso8601,
        updated_at: deal.updated_at.iso8601
      }
    end

    def self.attribution_rows(report)
      {
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
      }
    end
  end
end
