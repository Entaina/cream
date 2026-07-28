# frozen_string_literal: true

Llmemory.configure do |config|
  config.llm_provider = :openai
  config.llm_api_key = ENV["CREAM_AI_API_KEY"]
  config.llm_model = ENV.fetch("CREAM_AI_MODEL", "gpt-4.1-mini")

  if Rails.env.test?
    config.short_term_store = :memory
    config.long_term_store = :memory
  else
    config.short_term_store = :active_record
    config.long_term_store = :active_record
  end

  config.long_term_type = :file_based
  config.auto_recall_enabled = false
  config.memory_flush_enabled = true
  config.memory_flush_threshold_tokens = 4000

  if ENV["LLMEMORY_ENCRYPTION_KEY"].present?
    config.encryption_enabled = true
    config.encryption_key = ENV["LLMEMORY_ENCRYPTION_KEY"]
  end
end
