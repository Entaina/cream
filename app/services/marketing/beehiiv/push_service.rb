module Marketing
  module Beehiiv
    class PushService
      def self.subscribe!(connection:, person:, reactivate: false)
        new(connection).subscribe!(person:, reactivate:)
      end

      def self.unsubscribe!(connection:, person:)
        new(connection).unsubscribe!(person:)
      end

      def initialize(connection)
        @connection = connection
        @workspace = connection.workspace
        @client = Client.new(connection)
      end

      def subscribe!(person:, reactivate: false)
        return unless person.email.present?

        SubscriptionType.ensure_defaults!(@workspace)
        newsletter_type = @workspace.subscription_types.active.find_by!(slug: "newsletter")
        subscription = EmailSubscription.find_by(person: person, subscription_type: newsletter_type)

        response = @client.create_subscription(
          email: person.email,
          reactivate_existing: reactivate
        )
        sub_id = response.dig("data", "id")
        return if sub_id.blank?

        record = subscription || EmailSubscription.new(person: person, subscription_type: newsletter_type, workspace: @workspace)
        record.beehiiv_subscription_id = sub_id
        record.metadata = record.metadata.merge(
          "beehiiv_subscription_id" => sub_id,
          "beehiiv_pushed_at" => Time.current.iso8601
        )
        record.save! if record.changed?
      end

      def unsubscribe!(person:)
        return unless person.email.present?

        SubscriptionType.ensure_defaults!(@workspace)
        newsletter_type = @workspace.subscription_types.active.find_by!(slug: "newsletter")
        subscription = EmailSubscription.find_by(person: person, subscription_type: newsletter_type)
        sub_id = subscription&.beehiiv_subscription_id

        if sub_id.blank?
          remote = @client.find_subscription_by_email(person.email)
          sub_id = remote&.dig("id")
        end

        return if sub_id.blank?

        @client.unsubscribe(subscription_id: sub_id)
        subscription&.update!(
          beehiiv_subscription_id: sub_id,
          metadata: (subscription.metadata || {}).merge(
            "beehiiv_unsubscribed_at" => Time.current.iso8601
          )
        )
      end
    end
  end
end
