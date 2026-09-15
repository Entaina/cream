module Ai
  # Contextual agent: OKM knowledge + CRM read/write tools + llmemory.
  class ContextualAgent
    Result = Data.define(:reply, :pending_actions, :session_id)

    SYSTEM_PROMPT = <<~PROMPT.squish
      You are the commercial assistant inside Cream CRM. Answer in the same language as the user.
      You have tools to:
      - Search and read the OKM corporate knowledge base (PARA methodology)
      - Read CRM data (search records, get details, list tasks, pipeline summary)
      - Propose CRM changes (create tasks, add notes, update records, move deals, complete tasks)
      - Remember and recall facts about the user and clients
      Key OKM locations:
      - Areas/Clientes/<Company>/ — client context, transcripts, proposals
      - knowledge/Empresas/ — company profiles
      - knowledge/Personas/ — people profiles
      - Areas/Ventas/ — sales playbooks, battlecards, proposals methodology
      - Areas/Estrategia/ — positioning and strategy
      When CRM context is provided, combine it with OKM knowledge and stored memories.
      Cite sources by file name when possible. If you cannot find relevant information, say so clearly.
      OKM prefetch may already include search hits — use that first. Prefer at most one search_okm plus 1–2 file reads.
      CRM write tools only PROPOSE actions; tell the user they must confirm in the chat before changes apply.
      Never claim a CRM change was made unless the user has confirmed it.
    PROMPT

    MAX_TOOL_ITERATIONS = 12

    def initialize(workspace:, user:, message:, record: nil, history: [], session_id: nil,
      client: Ai::Client.new, drive: nil, on_status: nil, memory: nil)
      @workspace = workspace
      @user = user
      @record = record
      @message = message.to_s.strip
      @history = normalize_history(history)
      @client = client
      @drive = drive
      @on_status = on_status
      @memory = memory || build_memory(session_id)
      @pending_actions = []
      @registry = Agent::ToolRegistry.new(
        workspace: workspace,
        user: user,
        record: record,
        on_status: on_status,
        pending_actions: @pending_actions,
        memory: @memory,
        drive: drive
      )
    end

    def call
      raise Ai::Client::Error, "Message cannot be blank" if @message.blank?

      notify("Preparando contexto…")
      input = build_input

      notify("Consultando con IA…")
      reply = @client.chat_with_tools(
        system: SYSTEM_PROMPT,
        input: input,
        tools: @registry.definitions,
        max_iterations: MAX_TOOL_ITERATIONS
      ) { |name, args| @registry.execute(name, args) }

      @memory&.record_turn(user_message: @message, assistant_message: reply)
      @memory&.consolidate_later

      Result.new(reply: reply, pending_actions: @pending_actions.dup, session_id: @memory&.session_id)
    rescue Ai::Client::Error => e
      raise unless e.message.include?("Tool loop exceeded")

      Result.new(
        reply: "La consulta necesitó demasiadas búsquedas. Prueba una pregunta más concreta " \
               "(por ejemplo sobre un cliente, propuesta o tema de ventas específico).",
        pending_actions: [],
        session_id: @memory&.session_id
      )
    end

    private

    def build_input
      parts = []
      parts << "## CRM context\n#{crm_context}" if crm_context.present?
      parts << "## OKM prefetch\n#{okm_prefetch}" if okm_prefetch.present?
      parts << "## Memoria del usuario\n#{memory_context}" if memory_context.present?
      parts << format_history if @history.any?
      parts << "## User message\n#{@message}"
      parts.join("\n\n")
    end

    def okm_prefetch
      @okm_prefetch ||= @registry.prefetch_okm(record: @record, message: @message)
    end

    def memory_context
      return @memory_context if defined?(@memory_context)
      return @memory_context = "" unless @memory

      @memory_context = @memory.context_for(@message)
    end

    def crm_context
      @crm_context ||= begin
        contexts = []
        if @record
          contexts << RecordContextBuilder.new(record: @record, user: @user).to_prompt
          contexts.concat(related_record_contexts)
        end
        contexts.compact.join("\n\n")
      end
    end

    def related_record_contexts
      case @record
      when Person
        [company_context(@record.company)].compact
      when Deal
        [company_context(@record.company), *@record.contacts.map { |contact| person_context(contact) }].compact
      else
        []
      end
    end

    def company_context(company)
      return unless company

      JSON.pretty_generate(
        RecordContextBuilder.new(record: company, user: @user).to_h.merge(context_role: "related_company")
      )
    end

    def person_context(person)
      JSON.pretty_generate(
        RecordContextBuilder.new(record: person, user: @user).to_h.merge(context_role: "related_contact")
      )
    end

    def format_history
      lines = @history.map do |turn|
        role = turn[:role] || turn["role"]
        content = turn[:content] || turn["content"]
        next if role.blank? || content.blank?

        "#{role.capitalize}: #{content}"
      end.compact

      return "" if lines.empty?

      "## Conversation history\n#{lines.join("\n")}"
    end

    def normalize_history(history)
      Array(history).filter_map do |turn|
        role = turn[:role] || turn["role"]
        content = (turn[:content] || turn["content"]).to_s.strip
        next if role.blank? || content.blank?
        next unless %w[user assistant].include?(role.to_s)

        {role: role.to_s, content: content.first(4000)}
      end.last(20)
    end

    def build_memory(session_id)
      return nil unless memory_enabled?

      AgentMemory.new(workspace: @workspace, user: @user, session_id: session_id)
    end

    def memory_enabled?
      Ai::Configuration.configured?
    end

    def notify(message)
      @on_status&.call(message)
    end
  end
end
