module Ai
  # Reads LLM credentials from the environment. No secrets are persisted.
  class Configuration
    def self.configured?
      api_key.present?
    end

    def self.api_key
      ENV["CREAM_AI_API_KEY"].presence
    end

    def self.api_url
      ENV.fetch("CREAM_AI_API_URL", "https://api.openai.com/v1/responses")
    end

    def self.model
      ENV.fetch("CREAM_AI_MODEL", "gpt-4o-mini")
    end

    def self.timeout
      ENV.fetch("CREAM_AI_TIMEOUT", "120").to_i
    end

    # Reasoning models (gpt-5, o-series) reject the temperature parameter.
    UNSUPPORTED_TEMPERATURE_MODELS = /\A(o\d|gpt-5)/i

    def self.temperature
      return nil if model.match?(UNSUPPORTED_TEMPERATURE_MODELS)
      return ENV["CREAM_AI_TEMPERATURE"].to_f if ENV["CREAM_AI_TEMPERATURE"].present?

      0.2
    end
  end
end
