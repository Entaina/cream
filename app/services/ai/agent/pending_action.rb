module Ai
  module Agent
    # Signed CRM write proposal awaiting user confirmation in the chat UI.
    class PendingAction
      attr_reader :tool, :args, :description, :workspace_id, :user_id

      def initialize(tool:, args:, description:, workspace_id:, user_id:)
        @tool = tool.to_s
        @args = args.deep_stringify_keys
        @description = description
        @workspace_id = workspace_id
        @user_id = user_id
      end

      def sign
        self.class.verifier.generate(payload, expires_in: 15.minutes, purpose: :agent_pending_action)
      end

      def self.from_verified(token)
        data = verifier.verify(token, purpose: :agent_pending_action)
        new(
          tool: data["tool"],
          args: data["args"],
          description: data["description"],
          workspace_id: data["workspace_id"],
          user_id: data["user_id"]
        )
      end

      def payload
        {
          "tool" => tool,
          "args" => args,
          "description" => description,
          "workspace_id" => workspace_id,
          "user_id" => user_id
        }
      end

      def self.verifier
        Rails.application.message_verifier(:agent_actions)
      end
    end
  end
end
