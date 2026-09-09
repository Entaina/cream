module Marketing
  class MqlEligibility
    def self.scope(workspace:, subscription_type_id: nil)
      return workspace.people.none unless CreamFeatures.enabled?(:marketing_consent)

      type = resolve_subscription_type(workspace, subscription_type_id)
      return workspace.people.none unless type

      base = workspace.people.where.not(email: [ nil, "" ])
      subscribed_person_ids = workspace.email_subscriptions
        .where(subscription_type: type, status: "subscribed")
        .select(:person_id)

      without_suppressed_primary_email(base.where(id: subscribed_person_ids), workspace)
    end

    def self.eligible?(person, subscription_type_id: nil)
      return false unless CreamFeatures.enabled?(:marketing_consent)
      return false if person.email.blank?

      type = resolve_subscription_type(person.workspace, subscription_type_id)
      return false unless type

      subscription = EmailSubscription.find_by(person: person, subscription_type: type)
      return false unless subscription&.subscribed?
      return false if EmailSuppression.suppressed?(person.workspace, person.email)

      true
    end

    def self.resolve_subscription_type(workspace, subscription_type_id)
      if subscription_type_id.present?
        workspace.subscription_types.active.find_by(id: subscription_type_id)
      else
        SubscriptionType.ensure_defaults!(workspace)
        workspace.subscription_types.active.find_by(slug: "general") ||
          workspace.subscription_types.active.order(:id).first
      end
    end
    private_class_method :resolve_subscription_type

    def self.without_suppressed_primary_email(scope, workspace)
      scope.where(<<~SQL.squish, workspace.id)
        NOT EXISTS (
          SELECT 1 FROM email_suppressions
          WHERE email_suppressions.workspace_id = ?
            AND LOWER(TRIM(email_suppressions.address)) = LOWER(TRIM(people.email))
        )
      SQL
    end
    private_class_method :without_suppressed_primary_email
  end
end
