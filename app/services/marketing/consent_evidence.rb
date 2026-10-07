module Marketing
  # Evidence that a person consented to receive communications of a subscription type:
  # the exact text accepted and where it was obtained (both mandatory), plus an optional
  # date (defaults to the registration time) and IP. Used by every API/MCP entry point that
  # subscribes someone (MQL registration and subscription changes).
  class ConsentEvidence
    class Error < StandardError; end

    attr_reader :text, :source, :obtained_at, :ip

    # `entry` holds the `consent_text`, `consent_source`, `consent_obtained_at` and `consent_ip` keys.
    def self.parse(entry)
      entry = entry.to_unsafe_h if entry.respond_to?(:to_unsafe_h)
      entry = entry.to_h.with_indifferent_access.transform_values { |value| value.to_s.strip.presence }

      %i[consent_text consent_source].each do |field|
        raise Error, I18n.t("marketing.consent_evidence.errors.#{field}_required") if entry[field].blank?
      end

      new(
        text: entry[:consent_text], source: entry[:consent_source],
        obtained_at: parse_obtained_at(entry[:consent_obtained_at]), ip: validate_ip(entry[:consent_ip])
      )
    end

    def self.parse_obtained_at(value)
      return if value.blank?

      obtained_at = Time.zone.parse(value)
      raise Error, I18n.t("marketing.consent_evidence.errors.consent_obtained_at_invalid") if obtained_at.nil?
      raise Error, I18n.t("marketing.consent_evidence.errors.consent_obtained_at_future") if obtained_at > 5.minutes.from_now

      obtained_at.iso8601
    rescue ArgumentError
      raise Error, I18n.t("marketing.consent_evidence.errors.consent_obtained_at_invalid")
    end

    def self.validate_ip(value)
      return if value.blank?

      IPAddr.new(value)
      value
    rescue IPAddr::Error
      raise Error, I18n.t("marketing.consent_evidence.errors.consent_ip_invalid")
    end

    def initialize(text:, source:, obtained_at: nil, ip: nil)
      @text = text
      @source = source
      @obtained_at = obtained_at
      @ip = ip
    end

    # Metadata stored on the subscription, together with the user who registered the consent.
    def metadata(user:)
      {
        "marketing_consent_text" => text,
        "consent_source" => source,
        "consent_obtained_at" => obtained_at,
        "consent_ip" => ip,
        "recorded_by_user_id" => user.id,
        "recorded_by" => user.name
      }.compact
    end
  end
end
