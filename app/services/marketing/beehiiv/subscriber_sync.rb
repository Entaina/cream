module Marketing
  module Beehiiv
    class SubscriberSync
      ACTIVE_STATUSES = %w[active confirmed].freeze
      PENDING_STATUSES = %w[pending validating].freeze
      INACTIVE_STATUSES = %w[inactive].freeze
      INVALID_STATUSES = %w[invalid].freeze

      def self.apply!(publication:, record:, source: "beehiiv:sync", event_type: nil)
        new(publication:, record:, source:, event_type:).apply!
      end

      def initialize(publication:, record:, source:, event_type:)
        @publication = publication
        @connection = publication.beehiiv_connection
        @workspace = @connection.workspace
        @record = normalize_record(record)
        @source = source
        @event_type = event_type
      end

      def apply!
        email = @record[:email]
        return if email.blank?

        person = nil
        ActiveRecord::Base.transaction do
          lock_email!(email)
          person = find_or_create_person!(email)
          apply_subscription_state!(person)
        end

        Marketing::SegmentWatcher.sync_person!(person) if person
        person
      end

      private

      def normalize_record(record)
        data = record.is_a?(Hash) ? record.stringify_keys : {}
        data = data["data"].presence || data

        custom_fields = Array(data["custom_fields"]).each_with_object({}) do |field, hash|
          next unless field.is_a?(Hash)

          name = field["name"].to_s
          hash[name] = field["value"] if name.present?
        end

        {
          id: data["id"].presence,
          email: data["email"].to_s.strip.downcase,
          status: data["status"].to_s.downcase,
          utm_source: data["utm_source"],
          utm_medium: data["utm_medium"],
          utm_campaign: data["utm_campaign"],
          utm_term: data["utm_term"],
          utm_content: data["utm_content"],
          referring_site: data["referring_site"],
          created_at: parse_timestamp(data["created"] || data["created_at"]),
          custom_fields: custom_fields
        }
      end

      def parse_timestamp(value)
        return if value.blank?

        if value.is_a?(Numeric)
          Time.zone.at(value)
        else
          Time.zone.parse(value.to_s)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def lock_email!(email)
        ActiveRecord::Base.connection.execute(
          ActiveRecord::Base.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtext(?))", "beehiiv:#{@workspace.id}:#{email}" ])
        )
      end

      def find_or_create_person!(email)
        existing = @workspace.people.with_email(email).first
        return existing if existing

        first_name, last_name = names_from_record
        @workspace.people.create!(
          email: email,
          first_name: first_name,
          last_name: last_name.presence || "",
          company: LeadForm.placeholder_company_for(@workspace),
          source: "beehiiv"
        )
      end

      def names_from_record
        fields = @record[:custom_fields] || {}
        first = fields["First Name"].presence || fields["first_name"].presence
        last = fields["Last Name"].presence || fields["last_name"].presence
        return [ first, last ] if first.present?

        local = @record[:email].to_s.split("@").first.to_s
        [ local.presence || "Suscriptor", last ]
      end

      def apply_subscription_state!(person)
        subscription_type = @publication.subscription_type
        subscription = EmailSubscription.find_or_initialize_by(person: person, subscription_type: subscription_type)
        subscription.workspace = @workspace
        subscription.beehiiv_subscription_id = @record[:id] if @record[:id].present?

        metadata = subscription.metadata.merge(beehiiv_metadata)
        cream_status = map_status

        case cream_status
        when "subscribed"
          subscription.update!(
            status: "subscribed",
            opted_in_at: subscription.opted_in_at || @record[:created_at] || Time.current,
            opted_out_at: nil,
            source: @source,
            legal_basis: "consent",
            metadata: metadata
          )
        when "pending"
          subscription.update!(
            status: "pending",
            source: @source,
            legal_basis: "consent",
            metadata: metadata
          )
        when "unsubscribed"
          subscription.update!(
            status: "unsubscribed",
            opted_out_at: Time.current,
            source: @source,
            metadata: metadata
          )
        end

        if INVALID_STATUSES.include?(@record[:status])
          EmailSuppression.suppress!(
            workspace: @workspace,
            address: person.email,
            reason: "hard_bounce",
            metadata: { "source" => @source, "beehiiv_subscription_id" => @record[:id] }.compact
          )
        end
      end

      def map_status
        status = @record[:status]
        event = @event_type.to_s

        return "subscribed" if event == "subscription.confirmed"
        return "unsubscribed" if event == "subscription.deleted"
        return "subscribed" if ACTIVE_STATUSES.include?(status)
        return "pending" if PENDING_STATUSES.include?(status)
        return "unsubscribed" if INACTIVE_STATUSES.include?(status) || INVALID_STATUSES.include?(status)

        "pending"
      end

      def beehiiv_metadata
        {
          "beehiiv_subscription_id" => @record[:id],
          "beehiiv_publication_id" => @publication.publication_id,
          "beehiiv_status" => @record[:status],
          "beehiiv_event_type" => @event_type,
          "utm_source" => @record[:utm_source],
          "utm_medium" => @record[:utm_medium],
          "utm_campaign" => @record[:utm_campaign],
          "utm_term" => @record[:utm_term],
          "utm_content" => @record[:utm_content],
          "referring_site" => @record[:referring_site],
          "synced_at" => Time.current.iso8601
        }.compact.stringify_keys
      end
    end
  end
end
