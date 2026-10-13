require "mcp/server_context"
require "mcp/progress"

module Ai
  module Agent
    # Exposes Cream MCP tools to the in-app assistant.
    # Reads run immediately. Writes are proposed and only run after chat confirmation.
    class McpTools
      READ_ONLY = %w[
        search_records list_people list_companies list_deals get_record
        list_products list_tasks list_my_tasks list_emails get_email list_activity list_payments
        list_pipelines list_stage_conditions list_person_duplicates list_company_duplicates
        pipeline_summary list_custom_fields get_deal_history recent_changes sales_forecast
        summarize_record suggest_next_steps draft_email natural_language_search enrich_record
        list_mqls get_person_marketing list_product_interests list_subscription_types list_subscriptions
        list_campaigns get_campaign list_segments get_segment list_journeys get_journey
        list_scoring_rules get_attribution list_email_templates list_lead_forms
      ].freeze

      WRITE = %w[
        create_stage_condition update_stage_condition delete_stage_condition
        create_person create_company create_deal
        update_person update_company update_deal update_deal_stage
        merge_person merge_company delete_record
        create_product update_product add_deal_product update_deal_product update_task
        add_note add_person_attachment add_deal_offer add_comment send_deal_email create_task complete_task
        set_custom_fields
        create_mql create_product_interest convert_mql_to_sql set_subscription
        enroll_in_journey send_campaign cancel_campaign_send
      ].freeze

      MAX_OUTPUT = 12_000

      Outcome = Data.define(:known, :success, :message, :data)

      def initialize(workspace:, user:, pending_actions:, on_status: nil, write: true)
        @workspace = workspace
        @user = user
        @pending_actions = pending_actions
        @on_status = on_status
        @write = write
      end

      def definitions
        available_tools.map { |tool| function_definition(tool) }
      end

      def try_execute(name, args)
        tool = self.class.tool(name)
        return nil unless tool
        return "Forbidden: this assistant cannot change CRM data." if !@write && !self.class.read_only?(name)

        args = args.to_h
        if self.class.read_only?(name)
          execute_tool(tool, args)
        else
          propose(tool, args)
        end
      rescue => e
        "Tool error: #{e.message}"
      end

      def self.execute_confirmed(workspace:, user:, name:, args:)
        tool = self.tool(name)
        return Outcome.new(known: false, success: false, message: nil, data: nil) unless tool && !read_only?(name)

        text = new(workspace: workspace, user: user, pending_actions: []).execute_tool(tool, args)
        failure = failure_message(text)
        if failure
          Outcome.new(known: true, success: false, message: failure, data: nil)
        else
          Outcome.new(known: true, success: true, message: "Hecho (#{name}). #{text.truncate(400)}", data: nil)
        end
      rescue => e
        Outcome.new(known: true, success: false, message: e.message, data: nil)
      end

      def self.read_only?(name)
        READ_ONLY.include?(name.to_s)
      end

      def self.tool(name)
        tools_by_name[name.to_s]
      end

      def self.tools_by_name
        @tools_by_name ||= CreamMcp.tools.index_by { |tool| tool.name_value }
      end

      def execute_tool(tool, args)
        notify("Consultando #{tool.name_value}…")
        response = tool.call(**symbolize_args(args), server_context: server_context)
        response_text(response).truncate(MAX_OUTPUT)
      end

      private

      def available_tools
        self.class.tools_by_name.values.select { |tool| @write || self.class.read_only?(tool.name_value) }
      end

      def function_definition(tool)
        description = tool.description_value.to_s
        unless self.class.read_only?(tool.name_value)
          description += " Requires user confirmation before it runs. Do not claim the change was made."
        end

        {
          type: "function",
          name: tool.name_value,
          description: description,
          parameters: parameters_for(tool)
        }
      end

      def parameters_for(tool)
        schema = tool.input_schema.to_h.deep_stringify_keys
        schema.delete("$schema")
        schema
      end

      def propose(tool, args)
        notify("Preparando #{tool.name_value}…")
        description = confirmation_description(tool, args)
        @pending_actions << PendingAction.new(
          tool: tool.name_value,
          args: args,
          description: description,
          workspace_id: @workspace.id,
          user_id: @user.id
        )
        "Acción propuesta: #{description}. Pendiente de confirmación del usuario. No se ha ejecutado aún."
      end

      def confirmation_description(tool, args)
        detail = args.except("content", "attachments", "body").filter_map { |key, value|
          next if value.blank?

          "#{key}: #{value.to_s.truncate(60)}"
        }.first(4).join(", ")
        [tool.name_value.tr("_", " "), detail.presence].compact.join(" — ")
      end

      def server_context
        MCP::ServerContext.new(
          {user: @user, workspace: @workspace},
          progress: MCP::Progress.new(notification_target: nil, progress_token: nil),
          notification_target: nil
        )
      end

      def symbolize_args(args)
        args.to_h.transform_keys(&:to_sym)
      end

      def response_text(response)
        parts = Array(response.respond_to?(:content) ? response.content : nil)
        text = parts.filter_map { |part|
          if part.is_a?(Hash)
            part[:text] || part["text"]
          elsif part.respond_to?(:text)
            part.text
          end
        }.join("\n")
        text.presence || JSON.generate(response.to_h)
      end

      def notify(message)
        @on_status&.call(message)
      end

      def self.failure_message(text)
        parsed = JSON.parse(text.to_s)
        return unless parsed.is_a?(Hash) && parsed["error"].present?

        parsed["message"].presence || parsed["error"].to_s
      rescue JSON::ParserError
        nil
      end
      private_class_method :failure_message
    end
  end
end
