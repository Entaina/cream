module ClientPortal
  # Subscriptions shown on the portal confirmation screens. Optional ones only go to people who never answered
  # (an unsubscribe is an answer) and aren't suppressed; required ones go to anyone not subscribed, since
  # they gate access.
  class ConsentOffer
    def self.types_for(workspace:, email:)
      return SubscriptionType.none unless CreamFeatures.enabled?(:marketing_consent)
      return SubscriptionType.none if email.blank?

      subscriptions = EmailSubscription.where(person_id: workspace.people.with_email(email).select(:id))
      offered = workspace.subscription_types.offered_in_client_portal

      required_ids = offered.where(client_portal_consent: "required")
        .where.not(id: subscriptions.where(status: "subscribed").select(:subscription_type_id)).select(:id)
      optional_ids = if EmailSuppression.suppressed?(workspace, email)
        SubscriptionType.none.select(:id)
      else
        offered.where(client_portal_consent: "optional")
          .where.not(id: subscriptions.where(status: %w[subscribed unsubscribed]).select(:subscription_type_id)).select(:id)
      end

      offered.where(id: required_ids).or(offered.where(id: optional_ids)).ordered
    end

    def self.missing_required?(types, type_ids)
      ids = Array(type_ids).map(&:to_s)
      types.any? { |type| type.client_portal_required? && !ids.include?(type.id.to_s) }
    end

    def self.record!(workspace:, person:, type_ids:, request:, context:)
      ids = Array(type_ids).map(&:to_s)
      return [] if ids.empty?

      types = types_for(workspace: workspace, email: person.email).select { |type| ids.include?(type.id.to_s) }
      return [] if types.empty?

      statement = types.map(&:consent_label).join("\n")
      version = PrivacyPolicy.snapshot(workspace: workspace, statement_html: statement)
      metadata = {
        "consent_source" => "client_portal:#{context}",
        "consent_obtained_at" => Time.current.iso8601,
        "consent_locale" => I18n.locale.to_s,
        "consent_ip" => request.remote_ip,
        "user_agent" => request.user_agent,
        "privacy_policy_url" => (Rails.application.routes.url_helpers.client_portal_privacy_url(workspace_slug: workspace.slug, **url_options) if version),
        "privacy_policy_version_id" => version&.id,
        "privacy_policy_hash" => version&.content_hash
      }.compact

      types.map do |type|
        Marketing::ConsentService.subscribe!(
          person: person,
          subscription_type: type,
          source: "client_portal:#{context}",
          legal_basis: "consent",
          metadata: metadata.merge(
            "marketing_consent_text" => type.consent_label,
            "client_portal_required" => type.client_portal_required?
          )
        )
      end
    end

    def self.url_options
      Rails.application.config.action_mailer.default_url_options.to_h.slice(:host, :port, :protocol)
    end
    private_class_method :url_options
  end
end
