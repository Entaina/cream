module Ai
  class EmailDrafter
    SYSTEM = <<~TEXT.squish
      You are a CRM assistant for Cream. Draft a professional follow-up email.
      Respond ONLY with valid JSON using keys: subject (string), body (string).
      Keep the tone concise and helpful. Use plain text in the body, no HTML.
      Base the draft only on the provided CRM context and user goal.
    TEXT

    def initialize(record:, user: nil, goal: nil, client: Client.new)
      @record = record
      @user = user
      @goal = goal.presence || default_goal
      @client = client
      @context = RecordContextBuilder.new(record: record, user: user)
    end

    def call
      raw = @client.chat(
        system: SYSTEM,
        user: <<~PROMPT,
          Goal: #{@goal}

          CRM record context:
          #{@context.to_prompt}
        PROMPT
        json: true
      )
      payload = JsonParser.parse(raw)
      {
        subject: payload["subject"].to_s.strip,
        body: payload["body"].to_s.strip
      }
    end

    private

    def default_goal
      case @record
      when Deal then "Write a follow-up email about this deal."
      when Person then "Write a friendly follow-up email to this contact."
      when Company then "Write a follow-up email about working with this company."
      else "Write a follow-up email."
      end
    end
  end
end
