module Marketing
  class ConsentService
    def self.propagate_from_lead_form!(person:, workspace:, params:, request:, lead_form:)
      return unless CreamFeatures.enabled?(:marketing_consent)

      SubscriptionType.ensure_defaults!(workspace)
      newsletter_type = workspace.subscription_types.find_by!(slug: "newsletter")

      if params["newsletter_opt_in"] == "1" || params["newsletter_opt_in"] == true
        subscribe!(
          person: person,
          subscription_type: newsletter_type,
          source: "lead_form:#{lead_form.slug}",
          legal_basis: "consent",
          metadata: consent_metadata(params:, request:, lead_form:)
        )
      end
    end

    def self.gdpr_audit_metadata(params:, request:, lead_form:)
      return {} unless params["gdpr_consent"] == "1" || params["gdpr_consent"] == true

      consent_metadata(params:, request:, lead_form:).merge("gdpr_consent_at" => Time.current.iso8601)
    end

    def self.subscribe!(person:, subscription_type:, source:, legal_basis: nil, metadata: {})
      subscription = EmailSubscription.find_or_initialize_by(person: person, subscription_type: subscription_type)
      subscription.workspace = subscription_type.workspace
      subscription.subscribe!(source: source, legal_basis: legal_basis, metadata: metadata)
      subscription
    end

    def self.unsubscribe!(person:, subscription_type:, source: "preference_center", metadata: {})
      subscription = EmailSubscription.find_by(person: person, subscription_type: subscription_type)
      return unless subscription

      subscription.unsubscribe!(source: source, metadata: metadata)
    end

    def self.unsubscribe_all!(person:, source: "preference_center", metadata: {})
      workspace = person.workspace
      workspace.subscription_types.active.find_each do |type|
        unsubscribe!(person: person, subscription_type: type, source: source, metadata: metadata)
      end
      EmailSuppression.suppress!(
        workspace: workspace,
        address: person.email,
        reason: "unsubscribe",
        metadata: metadata.merge("scope" => "all")
      )
    end

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
    private_class_method :consent_metadata
  end
end
