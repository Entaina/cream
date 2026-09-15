module Marketing
  class CampaignSender
    BATCH_SIZE = Marketing::Esp::Client::BATCH_SIZE

    def self.call(campaign_send:)
      new(campaign_send).call
    end

    def initialize(campaign_send)
      @campaign_send = campaign_send
      @campaign = campaign_send.campaign
      @segment = campaign_send.segment
      @workspace = campaign_send.workspace
      @email_content = @campaign.email_content
      @user = campaign_send.user
      @subscription_type = campaign_send.subscription_type || default_subscription_type
    end

    def call
      return unless CreamFeatures.enabled?(:marketing_campaigns)
      return if @campaign_send.status == "cancelled"
      return mark_empty_failure! unless @email_content.present?

      @campaign_send.mark_started!
      @campaign.update!(status: "sending")

      recipients = resolve_recipients
      sent = 0
      skipped = 0
      failed = 0
      last_error = nil

      recipients.each_slice(BATCH_SIZE) do |batch|
        batch.each do |person, email|
          result = deliver_to(person, email)
          case result
          when :sent then sent += 1
          when :skipped then skipped += 1
          when :failed
            failed += 1
            last_error = @last_error
          end
        end
        sleep 0.1
      end

      stats = {"sent" => sent, "skipped" => skipped, "failed" => failed}
      stats["last_error"] = last_error if last_error.present?

      if sent.zero? && failed.positive?
        @campaign_send.mark_failed!(stats: stats)
        @campaign.update!(status: "draft")
      else
        @campaign_send.mark_completed!(stats: stats)
        @campaign.update!(status: "sent")
      end
    end

    private

    attr_reader :subscription_type, :email_content

    def default_subscription_type
      SubscriptionType.ensure_defaults!(@workspace)
      @workspace.subscription_types.find_by(slug: "newsletter")
    end

    def mark_empty_failure!
      @campaign_send.mark_failed!(stats: {"sent" => 0, "skipped" => 0, "failed" => 0, "last_error" => "missing_email_content"})
      @campaign.update!(status: "draft")
    end

    def resolve_recipients
      people = @segment.resolve(@workspace.people.includes(:person_emails))
      entries = people.flat_map { |person| recipient_entries_for(person) }
      allowed = Marketing::SendGuard.filter_addresses(
        workspace: @workspace,
        addresses: entries.map(&:last),
        subscription_type: subscription_type
      )
      allowed_set = allowed.map { |address| address.to_s.downcase.strip }.to_set
      seen = Set.new
      entries.select do |_person, email|
        normalized = email.to_s.downcase.strip
        next false if normalized.blank? || seen.include?(normalized) || !allowed_set.include?(normalized)

        seen.add(normalized)
        true
      end
    end

    def recipient_entries_for(person)
      addresses = [person.email, *person.person_emails.map(&:address)].map(&:presence).compact.uniq
      addresses.map { |address| [person, address] }
    end

    def deliver_to(person, email)
      return :skipped if email.blank?
      return :skipped unless Marketing::SendGuard.allowed?(workspace: @workspace, address: email, subscription_type: subscription_type)

      variant = pick_variant(email)
      subject, body = if variant
        email_content.render_custom_for(person, subject: variant.subject, body: variant.body)
      else
        [email_content.render_subject_for(person), email_content.render_for(person)]
      end

      message = @workspace.email_messages.create!(
        user: @user,
        record: person,
        to_address: email,
        subject: subject,
        body: body,
        campaign: @campaign,
        campaign_variant: variant,
        marketing_send: true
      )
      email_content.attach_to(message)
      delivered = Marketing::Esp::Client.for(message, subscription_type: subscription_type).deliver!
      unless delivered
        @last_error = "ESP delivery failed"
        message.update!(status: "failed")
        return :failed
      end

      Marketing::ScoringEngine.apply_event!(person: person, event: "email_sent", metadata: {"campaign_id" => @campaign.id})
      :sent
    rescue => e
      @last_error = e.message
      :failed
    end

    def pick_variant(email)
      variants = @campaign_send.campaign_variants.to_a
      CampaignVariant.pick_for_email(variants, email)
    end
  end
end
