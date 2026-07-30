module Ai
  module Agent
    # Aggregates tool definitions and dispatches execution to tool groups.
    class ToolRegistry
      def initialize(workspace:, user:, record: nil, on_status: nil, pending_actions: [], memory: nil,
        drive: nil, write: true, okm: workspace.okm_configured?)
        @ctx = UserContext.new(user: user, workspace: workspace)
        @record = record
        @pending_actions = pending_actions
        @groups = []
        @groups << OkmTools.new(drive: drive || Okm::DriveClient.new(workspace: workspace), on_status: on_status) if okm
        @groups << CrmReadTools.new(ctx: @ctx, on_status: on_status)
        @groups << CrmWriteTools.new(ctx: @ctx, pending_actions: pending_actions, on_status: on_status) if write
        @groups << MemoryTools.new(memory: memory, on_status: on_status) if memory
      end

      def definitions
        @groups.flat_map(&:definitions)
      end

      def execute(name, args)
        @groups.each do |group|
          result = group.try_execute(name, args)
          return result unless result.nil?
        end

        "Unknown tool: #{name}"
      end

      def prefetch_okm(record:, message:)
        okm_group&.prefetch(record: record, message: message).to_s
      end

      private

      def okm_group
        @groups.find { |group| group.is_a?(OkmTools) }
      end
    end
  end
end
