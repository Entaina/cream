module Ai
  module Agent
    # Signed CRM write proposal awaiting user confirmation in the chat UI.
    # Each token runs at most once: its nonce is consumed before execution.
    class PendingAction
      TTL = 15.minutes

      attr_reader :tool, :args, :description, :preview, :workspace_id, :user_id, :nonce

      def initialize(tool:, args:, description:, workspace_id:, user_id:, preview: nil, nonce: SecureRandom.uuid)
        @tool = tool.to_s
        @args = args.deep_stringify_keys
        @description = description
        @preview = preview
        @workspace_id = workspace_id
        @user_id = user_id
        @nonce = nonce
      end

      def sign
        self.class.verifier.generate(payload, expires_in: TTL, purpose: :agent_pending_action)
      end

      def self.from_verified(token)
        data = verifier.verify(token, purpose: :agent_pending_action)
        new(
          tool: data["tool"],
          args: data["args"],
          description: data["description"],
          workspace_id: data["workspace_id"],
          user_id: data["user_id"],
          nonce: data["nonce"]
        )
      end

      # True only the first time it is called for this token.
      def consume!
        return false if nonce.blank?

        Rails.cache.write("agent_action:#{nonce}", true, unless_exist: true, expires_in: TTL)
      end

      def payload
        {
          "tool" => tool,
          "args" => args,
          "description" => description,
          "workspace_id" => workspace_id,
          "user_id" => user_id,
          "nonce" => nonce
        }
      end

      def self.verifier
        Rails.application.message_verifier(:agent_actions)
      end
    end
  end
end
