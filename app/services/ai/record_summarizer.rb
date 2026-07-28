module Ai
  class RecordSummarizer
    SYSTEM = <<~TEXT.squish
      You are a CRM assistant for Cream. Summarize the record context for a sales team.
      Respond ONLY with valid JSON using keys: summary (string), risks (array of strings),
      next_steps (array of strings), missing_data (array of strings).
      Be concise, factual, and base everything on the provided context only.
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
        user: "Summarize this CRM record:\n\n#{@context.to_prompt}",
        json: true
      )
      normalize(JsonParser.parse(raw))
    end

    private

    def normalize(payload)
      {
        summary: payload["summary"].to_s.strip,
        risks: Array(payload["risks"]).map(&:to_s).reject(&:blank?),
        next_steps: Array(payload["next_steps"]).map(&:to_s).reject(&:blank?),
        missing_data: Array(payload["missing_data"]).map(&:to_s).reject(&:blank?)
      }
    end
  end
end
