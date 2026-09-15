module Marketing
  class ConsentService
    SUBSCRIBE_ALL_FIELD_KEY = "subscribe_all".freeze

    LEGACY_FIELD_ALIASES = {
      "newsletter" => "newsletter_opt_in",
      "general" => "marketing_consent"
    }.freeze

    def self.propagate_from_lead_form!(person:, workspace:, params:, request:, lead_form:, privacy_policy_version: nil)
      propagate_subscription_fields!(
        person: person,
        workspace: workspace,
        params: params,
        request: request,
        lead_form: lead_form,
        privacy_policy_version: privacy_policy_version
      )
    end

    def self.propagate_subscription_fields!(person:, workspace:, params:, request:, lead_form:, privacy_policy_version: nil, extra_metadata: {})
      return unless CreamFeatures.enabled?(:marketing_consent)

      SubscriptionType.ensure_defaults!(workspace)
      base_metadata = consent_metadata(params:, request:, lead_form:).merge(extra_metadata).merge(
        privacy_policy_trace(privacy_policy_version:, params:, lead_form:)
      )

      subscribe_all = subscribe_all_checked?(params)
      subscribe_all_types = if subscribe_all
        subscribe_all_types_for(
          workspace,
          additional_exclude_slugs: subscribe_all_exclude_slugs_from(params)
        )
      end
      subscribe_all_type_ids = subscribe_all_types&.map(&:id) || []
      subscribe_all_metadata = subscribe_all ? subscribe_all_metadata_for(subscribe_all_types, params: params) : {}

      workspace.subscription_types.active.ordered.each do |type|
        should_subscribe = if subscribe_all
          subscribe_all_type_ids.include?(type.id)
        else
          per_type_consent_checked?(params, type)
        end
        next unless should_subscribe

        metadata = base_metadata.dup
        metadata.merge!(subscribe_all_metadata) if subscribe_all
        if primary_mql_subscription_type?(lead_form, type) && lead_form.marketing_consent_text.present?
          metadata["marketing_consent_text"] = lead_form.marketing_consent_text
        end

        subscribe!(
          person: person,
          subscription_type: type,
          source: "lead_form:#{lead_form.slug}",
          legal_basis: "consent",
          metadata: metadata
        )
      end
    end

    def self.subscribe_all_checked?(params)
      params[SUBSCRIBE_ALL_FIELD_KEY] == "1" || params[SUBSCRIBE_ALL_FIELD_KEY] == true
    end

    def self.subscribe_all_types_for(workspace, additional_exclude_slugs: [])
      excluded_slugs = workspace.subscription_types.active.where(excluded_from_subscribe_all: true).pluck(:slug)
      excluded_slugs.concat(normalize_exclude_slugs(additional_exclude_slugs))
      excluded_slugs.uniq!

      workspace.subscription_types.active.ordered.reject { |type| excluded_slugs.include?(type.slug) }
    end

    def self.subscribe_all_exclude_slugs_from(params)
      normalize_exclude_slugs(params["subscribe_all_exclude_slugs"].to_s.split(","))
    end

    def self.normalize_exclude_slugs(slugs)
      Array(slugs).map { |slug| slug.to_s.strip }.reject(&:blank?)
    end
    private_class_method :normalize_exclude_slugs

    def self.subscribe_all_default_label(active_types)
      names = active_types.map(&:name).join(", ")
      "Quiero recibir todas las comunicaciones (#{names})"
    end

    def self.subscribe_all_metadata_for(active_types, params:)
      {
        "subscribe_all" => true,
        "subscribe_all_label" => params["subscribe_all_label"].presence || subscribe_all_default_label(active_types),
        "subscribe_all_type_slugs" => active_types.map(&:slug)
      }
    end

    def self.per_type_consent_checked?(params, subscription_type)
      field_key_for(subscription_type).present? && consent_param_checked?(params, subscription_type)
    end

    def self.consent_param_checked?(params, subscription_type)
      field_key_for(subscription_type).present? &&
        (params[field_key_for(subscription_type)] == "1" || params[field_key_for(subscription_type)] == true)
    end

    def self.field_key_for(subscription_type)
      subscription_type.consent_field_key.presence || LEGACY_FIELD_ALIASES[subscription_type.slug]
    end

    def self.primary_mql_subscription_type?(lead_form, subscription_type)
      lead_form.mql_destination? && lead_form.mql_subscription_type&.id == subscription_type.id
    end

    def self.gdpr_audit_metadata(params:, request:, lead_form:, privacy_policy_version: nil)
      return {} unless params["gdpr_consent"] == "1" || params["gdpr_consent"] == true

      consent_metadata(params:, request:, lead_form:).merge(
        "gdpr_consent_at" => Time.current.iso8601
      ).merge(
        privacy_policy_trace(privacy_policy_version:, params:, lead_form:)
      )
    end

    def self.subscribe!(person:, subscription_type:, source:, legal_basis: nil, metadata: {})
      subscription = EmailSubscription.find_or_initialize_by(person: person, subscription_type: subscription_type)
      subscription.workspace = subscription_type.workspace
      reactivate = subscription.persisted? && !subscription.subscribed?
      subscription.subscribe!(source: source, legal_basis: legal_basis, metadata: metadata)
      enqueue_beehiiv_push!(subscription, action: :subscribe, reactivate: reactivate, source: source)
      subscription
    end

    def self.unsubscribe!(person:, subscription_type:, source: "preference_center", metadata: {}, push_to_beehiiv: true)
      subscription = EmailSubscription.find_by(person: person, subscription_type: subscription_type)
      return unless subscription

      subscription.unsubscribe!(source: source, metadata: metadata)
      enqueue_beehiiv_push!(subscription, action: :unsubscribe, source: source) if push_to_beehiiv
      subscription
    end

    def self.unsubscribe_all!(person:, source: "preference_center", metadata: {})
      workspace = person.workspace
      workspace.subscription_types.active.find_each do |type|
        unsubscribe!(person: person, subscription_type: type, source: source, metadata: metadata, push_to_beehiiv: false)
      end
      EmailSuppression.suppress!(
        workspace: workspace,
        address: person.email,
        reason: "unsubscribe",
        metadata: metadata.merge("scope" => "all")
      )
      enqueue_beehiiv_unsubscribe_all!(person, source: source)
    end

    def self.beehiiv_source?(source)
      source.to_s.start_with?("beehiiv:")
    end

    def self.enqueue_beehiiv_push!(subscription, action:, source:, reactivate: false)
      return if beehiiv_source?(source)

      connection = subscription.person.workspace.beehiiv_connection
      return unless connection&.connected?

      publication = connection.beehiiv_publications.find_by(subscription_type_id: subscription.subscription_type_id)
      return unless publication

      BeehiivPushJob.perform_later(
        publication.id,
        subscription.person_id,
        action.to_s,
        {"reactivate" => reactivate}
      )
    end
    private_class_method :enqueue_beehiiv_push!

    def self.enqueue_beehiiv_unsubscribe_all!(person, source:)
      return if beehiiv_source?(source)

      connection = person.workspace.beehiiv_connection
      return unless connection&.connected?

      connection.beehiiv_publications.find_each do |publication|
        BeehiivPushJob.perform_later(publication.id, person.id, "unsubscribe")
      end
    end
    private_class_method :enqueue_beehiiv_unsubscribe_all!

    def self.consent_metadata(params:, request:, lead_form:)
      {
        "lead_form_slug" => lead_form.slug,
        "ip" => request.remote_ip,
        "user_agent" => request.user_agent,
        "utm_source" => params["utm_source"],
        "utm_medium" => params["utm_medium"],
        "utm_campaign" => params["utm_campaign"]
      }.compact
    end

    def self.privacy_policy_trace(privacy_policy_version:, params:, lead_form:)
      trace = {"privacy_policy_url" => privacy_policy_url(lead_form)}

      if privacy_policy_version
        trace["privacy_policy_version_id"] = privacy_policy_version.id
        trace["privacy_policy_hash"] = privacy_policy_version.content_hash
      elsif params["privacy_policy_hash"].present?
        trace["privacy_policy_hash"] = params["privacy_policy_hash"]
        trace["privacy_policy_hash_unverified"] = true
      end

      trace.compact
    end

    def self.privacy_policy_url(lead_form)
      options = Rails.application.config.action_mailer.default_url_options
      host = options[:host]
      port = options[:port]
      host_with_port = port.present? ? "#{host}:#{port}" : host
      Rails.application.routes.url_helpers.public_lead_form_privacy_url(lead_form.slug, host: host_with_port)
    end
  end
end
