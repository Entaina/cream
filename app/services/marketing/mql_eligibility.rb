module Marketing
  class MqlEligibility
    def self.scope(workspace:, subscription_type_id: nil)
      return workspace.people.none unless CreamFeatures.enabled?(:marketing_consent)

      base = workspace.people.where.not(email: [nil, ""])
      subscribed_person_ids = subscribed_person_ids_for(workspace, subscription_type_id)
      return workspace.people.none unless subscribed_person_ids

      without_suppressed_primary_email(base.where(id: subscribed_person_ids), workspace)
    end

    def self.eligible?(person, subscription_type_id: nil)
      return false unless CreamFeatures.enabled?(:marketing_consent)
      return false if person.email.blank?

      unless subscribed_for?(person, subscription_type_id)
        return false
      end
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

    def self.subscribed_person_ids_for(workspace, subscription_type_id)
      if subscription_type_id.present?
        type = workspace.subscription_types.active.find_by(id: subscription_type_id)
        return nil unless type

        workspace.email_subscriptions
          .where(subscription_type: type, status: "subscribed")
          .select(:person_id)
      else
        active_type_ids = workspace.subscription_types.active.select(:id)
        workspace.email_subscriptions
          .where(subscription_type_id: active_type_ids, status: "subscribed")
          .select(:person_id)
      end
    end
    private_class_method :subscribed_person_ids_for

    def self.subscribed_for?(person, subscription_type_id)
      workspace = person.workspace
      if subscription_type_id.present?
        type = workspace.subscription_types.active.find_by(id: subscription_type_id)
        return false unless type

        subscription = EmailSubscription.find_by(person: person, subscription_type: type)
        subscription&.subscribed?
      else
        active_type_ids = workspace.subscription_types.active.pluck(:id)
        EmailSubscription.exists?(
          person: person,
          subscription_type_id: active_type_ids,
          status: "subscribed"
        )
      end
    end
    private_class_method :subscribed_for?

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
