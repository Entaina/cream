module Ai
  module Agent
    # Memory tools backed by llmemory (remember facts, recall context).
    class MemoryTools
      TOOLS = [
        {
          type: "function",
          name: "remember",
          description: "Store a fact or preference about the user or a client for future conversations.",
          parameters: {
            type: "object",
            properties: {
              content: { type: "string", description: "Fact to remember" },
              category: { type: "string", description: "Category (default: general)" }
            },
            required: [ "content" ],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "recall",
          description: "Search stored memories for relevant facts about the user or clients.",
          parameters: {
            type: "object",
            properties: {
              query: { type: "string", description: "What to recall" }
            },
            required: [ "query" ],
            additionalProperties: false
          }
        }
      ].freeze

      def initialize(memory:, on_status: nil)
        @memory = memory
        @on_status = on_status
      end

      def definitions
        return [] unless @memory

        TOOLS
      end

      def try_execute(name, args)
        return nil unless @memory

        case name
        when "remember" then execute_remember(args)
        when "recall" then execute_recall(args)
        else nil
        end
      end

      private

      def execute_remember(args)
        notify("Guardando en memoria…")
        @memory.remember_fact(
          content: args["content"],
          category: args["category"].presence || "general"
        )
        "Fact stored in memory."
      end

      def execute_recall(args)
        notify("Recuperando memoria…")
        context = @memory.context_for(args["query"])
        context.presence || "No relevant memories found."
      end

      def notify(message)
        @on_status&.call(message)
      end
    end
  end
end
