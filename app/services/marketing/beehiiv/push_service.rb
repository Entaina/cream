module Marketing
  module Beehiiv
    class PushService
      def self.subscribe!(publication:, person:, reactivate: false)
        new(publication).subscribe!(person:, reactivate:)
      end

      def self.unsubscribe!(publication:, person:)
        new(publication).unsubscribe!(person:)
      end

      def initialize(publication)
        @publication = publication
        @workspace = publication.workspace
        @client = Client.new(publication)
      end

      def subscribe!(person:, reactivate: false)
        return unless person.email.present?

        subscription = EmailSubscription.find_by(
          person: person,
          subscription_type: @publication.subscription_type
        )
        existing_id = resolve_beehiiv_subscription_id(subscription, person.email)

        if existing_id.present? && !reactivate
          persist_beehiiv_id!(subscription, existing_id, person: person)
          return
        end

        response = @client.create_subscription(
          email: person.email,
          reactivate_existing: reactivate
        )
        sub_id = response.dig("data", "id")
        return if sub_id.blank?

        persist_beehiiv_id!(subscription, sub_id, person: person)
      end

      def unsubscribe!(person:)
        return unless person.email.present?

        subscription_type = @publication.subscription_type
        subscription = EmailSubscription.find_by(person: person, subscription_type: subscription_type)
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
            "beehiiv_publication_id" => @publication.publication_id,
            "beehiiv_unsubscribed_at" => Time.current.iso8601
          )
        )
      end

      def resolve_beehiiv_subscription_id(subscription, email)
        sub_id = subscription&.beehiiv_subscription_id
        return sub_id if sub_id.present?

        remote = @client.find_subscription_by_email(email)
        remote&.dig("id")
      end

      def persist_beehiiv_id!(subscription, sub_id, person:)
        record = subscription || EmailSubscription.new(
          person: person,
          subscription_type: @publication.subscription_type,
          workspace: @workspace
        )

        record.beehiiv_subscription_id = sub_id
        record.metadata = (record.metadata || {}).merge(
          "beehiiv_subscription_id" => sub_id,
          "beehiiv_publication_id" => @publication.publication_id,
          "beehiiv_pushed_at" => Time.current.iso8601
        )
        record.save! if record.changed?
      end
    end
  end
end
