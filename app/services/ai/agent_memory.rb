module Ai
  # Wraps Llmemory::Memory for per-user, per-workspace agent memory.
  class AgentMemory
    TEAM_SCOPE = "sales_director_team"

    def initialize(workspace:, user:, session_id:, memory_scope: nil)
      @workspace = workspace
      @user = user
      @session_id = session_id.presence || SecureRandom.uuid
      @memory_scope = memory_scope
      @memory = Llmemory::Memory.new(user_id: memory_user_id, session_id: @session_id)
    end

    attr_reader :session_id

    def context_for(query)
      @memory.retrieve(query.to_s)
    rescue
      ""
    end

    def remember_fact(content:, category: "general")
      long_term = @memory.instance_variable_get(:@long_term)
      long_term.remember_fact(content: content, category: category)
    end

    def record_turn(user_message:, assistant_message:)
      @memory.add_message(role: :user, content: user_message)
      @memory.add_message(role: :assistant, content: assistant_message)
    end

    def consolidate_later
      AgentMemoryConsolidationJob.perform_later(memory_user_id, @session_id)
    end

    private

    def memory_user_id
      if @memory_scope == TEAM_SCOPE
        "ws_#{@workspace.id}:#{TEAM_SCOPE}"
      else
        "ws_#{@workspace.id}:user_#{@user.id}"
      end
    end
  end
end
