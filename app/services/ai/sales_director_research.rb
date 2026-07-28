module Ai
  # Gathers OKM, CRM and memory context for sales director briefings via agent tools.
  class SalesDirectorResearch
    SYSTEM = <<~TEXT.squish
      You are researching context for a sales director daily briefing in Cream CRM.
      Use OKM tools to find client playbooks, proposals, battlecards and sales methodology relevant to the deals in the snapshot.
      Use CRM read tools to inspect specific records when you need more detail.
      Use recall to check stored memories about clients, priorities and sales patterns.
      Do not propose CRM writes. After gathering enough context, respond with a concise Spanish summary
      of OKM insights, client-specific knowledge and relevant memories for today's briefing.
    TEXT

    MAX_TOOL_ITERATIONS = 8

    def initialize(workspace:, user:, briefing_date:, prefetch_terms: [], memory_scope: nil,
      client: Client.new, drive: nil, memory: nil)
      @workspace = workspace
      @user = user
      @briefing_date = briefing_date
      @prefetch_terms = Array(prefetch_terms).compact
      @memory_scope = memory_scope
      @client = client
      @drive = drive
      @memory = memory || build_memory
    end

    def call
      return "" unless enabled?

      registry = Agent::ToolRegistry.new(
        workspace: @workspace,
        user: @user,
        write: false,
        okm: Okm.configured?,
        memory: @memory,
        drive: @drive
      )
      return "" if registry.definitions.empty?

      notes = @client.chat_with_tools(
        system: SYSTEM,
        input: build_input(registry),
        tools: registry.definitions,
        max_iterations: MAX_TOOL_ITERATIONS
      ) { |name, args| registry.execute(name, args) }

      notes.to_s.strip
    rescue Client::Error => e
      Rails.logger.warn("[SalesDirectorResearch] #{e.class}: #{e.message}")
      ""
    end

    private

    def enabled?
      Ai::Configuration.configured?
    end

    def build_input(registry)
      parts = []
      parts << "## Fecha del briefing\n#{@briefing_date.iso8601}"
      parts << "## Memoria recuperada\n#{@memory.context_for(research_query)}" if @memory&.context_for(research_query).present?
      okm_prefetch = prefetch_okm(registry)
      parts << "## OKM prefetch\n#{okm_prefetch}" if okm_prefetch.present?
      parts << "## Términos de búsqueda sugeridos\n#{@prefetch_terms.join(", ")}" if @prefetch_terms.any?
      parts << "## Instrucción\nInvestiga el contexto comercial relevante para el briefing de hoy."
      parts.join("\n\n")
    end

    def prefetch_okm(registry)
      return "" unless Okm.configured?

      sections = @prefetch_terms.first(2).filter_map do |term|
        next if term.blank?

        registry.prefetch_okm(record: nil, message: term).presence
      end

      sections.join("\n\n")
    end

    def research_query
      "briefing ventas pipeline clientes #{@briefing_date.iso8601}"
    end

    def build_memory
      return nil unless Ai::Configuration.configured?

      AgentMemory.new(
        workspace: @workspace,
        user: @user,
        session_id: "briefing:#{@briefing_date}",
        memory_scope: @memory_scope
      )
    end
  end
end
