module Ai
  class NextStepSuggester
    SYSTEM = <<~TEXT.squish
      You are a CRM assistant for Cream. Suggest practical next steps for the sales team.
      Respond ONLY with valid JSON with keys:
      deal_risk (one of: low, medium, high),
      summary (string),
      suggestions (array of objects with keys: kind, title, due_on, reason).
      kind must be one of: task, email_follow_up, update_deal.
      due_on must be ISO date YYYY-MM-DD when kind is task, otherwise null.
      Prefer concrete, actionable suggestions grounded in the context.
    TEXT

    def initialize(record:, user: nil, client: Client.new)
      @record = record
      @user = user
      @client = client
      @context = RecordContextBuilder.new(record: record, user: user)
    end

    def call
      raw = @client.chat(
        system: SYSTEM,
        user: "Suggest next steps for this CRM record:\n\n#{@context.to_prompt}",
        json: true
      )
      normalize(JsonParser.parse(raw))
    end

    private

    def normalize(payload)
      suggestions = Array(payload["suggestions"]).filter_map do |item|
        next if item.blank?

        kind = item["kind"].to_s
        next unless %w[task email_follow_up update_deal].include?(kind)

        {
          kind: kind,
          title: item["title"].to_s.strip.presence,
          due_on: parse_date(item["due_on"]),
          reason: item["reason"].to_s.strip.presence
        }.compact
      end

      {
        deal_risk: normalize_risk(payload["deal_risk"]),
        summary: payload["summary"].to_s.strip,
        suggestions: suggestions
      }
    end

    def normalize_risk(value)
      risk = value.to_s.downcase
      %w[low medium high].include?(risk) ? risk : "medium"
    end

    def parse_date(value)
      return nil if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end
  end
end
