module Ai
  # Phase 2: suggest field updates from existing CRM context only (no external enrichment).
  class RecordEnricher
    SYSTEM = <<~TEXT.squish
      You are a CRM assistant for Cream. Suggest missing or improvable field values using ONLY
      the provided CRM context. Do not invent external facts such as funding, revenue, or LinkedIn
      profiles unless they already appear in the context.
      Respond ONLY with valid JSON using keys:
      summary (string),
      suggestions (array of objects with keys: field, current, suggested, reason).
      field must be one of the allowed fields listed in the prompt.
    TEXT

    ALLOWED_FIELDS = {
      Person => %w[job_title description location linkedin_url phone],
      Company => %w[industry domain employee_range location annual_revenue description],
      Deal => %w[probability expected_close_date]
    }.freeze

    def initialize(record:, user: nil, client: Client.new)
      @record = record
      @user = user
      @client = client
      @context = RecordContextBuilder.new(record: record, user: user)
    end

    def call
      raw = @client.chat(
        system: SYSTEM,
        user: <<~PROMPT,
          Allowed fields: #{allowed_fields.join(", ")}

          Current values:
          #{current_values.to_json}

          CRM record context:
          #{@context.to_prompt}
        PROMPT
        json: true
      )
      normalize(JsonParser.parse(raw))
    end

    private

    def allowed_fields
      ALLOWED_FIELDS.fetch(@record.class, [])
    end

    def current_values
      allowed_fields.index_with { |field| @record.public_send(field) }
    end

    def normalize(payload)
      allowed = allowed_fields
      suggestions = Array(payload["suggestions"]).filter_map do |item|
        field = item["field"].to_s
        next unless allowed.include?(field)

        suggested = item["suggested"]
        next if suggested.blank?

        {
          field: field,
          current: item["current"],
          suggested: suggested,
          reason: item["reason"].to_s.strip.presence
        }.compact
      end

      {
        summary: payload["summary"].to_s.strip,
        suggestions: suggestions
      }
    end
  end
end
