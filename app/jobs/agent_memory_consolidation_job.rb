class AgentMemoryConsolidationJob < ApplicationJob
  queue_as :default

  def perform(memory_user_id, session_id)
    memory = Llmemory::Memory.new(user_id: memory_user_id, session_id: session_id)
    memory.consolidate!
  rescue => e
    Rails.logger.warn("[AgentMemoryConsolidationJob] #{e.class}: #{e.message}")
  end
end
