module Ai
  class JsonParser
    def self.parse(text)
      JSON.parse(clean(text))
    rescue JSON::ParserError => e
      raise Ai::Client::Error, "Invalid JSON from model: #{e.message}"
    end

    def self.clean(text)
      stripped = text.to_s.strip
      if stripped.start_with?("```")
        stripped = stripped.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
      end
      stripped
    end
  end
end
