module Ai
  module Agent
    # Executes a confirmed CRM write action after token verification and Pundit checks.
    class ActionExecutor
      RECORD_TYPES = %w[person company deal].freeze

      Result = Data.define(:success, :message, :data)

      def initialize(workspace:, user:)
        @ctx = UserContext.new(user: user, workspace: workspace)
      end

      def execute(action)
        case action.tool
        when "create_task" then execute_create_task(action.args)
        when "add_note" then execute_add_note(action.args)
        when "update_record" then execute_update_record(action.args)
        when "update_deal_stage" then execute_update_deal_stage(action.args)
        when "complete_task" then execute_complete_task(action.args)
        else
          outcome = McpTools.execute_confirmed(
            workspace: @ctx.workspace, user: @ctx.user, name: action.tool, args: action.args
          )
          if outcome.known
            Result.new(success: outcome.success, message: outcome.message, data: outcome.data)
          else
            Result.new(success: false, message: "Unknown action: #{action.tool}", data: nil)
          end
        end
      rescue ActiveRecord::RecordNotFound
        Result.new(success: false, message: "Record not found.", data: nil)
      rescue Pundit::NotAuthorizedError => e
        Result.new(success: false, message: "Forbidden: #{e.message}", data: nil)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success: false, message: e.record.errors.full_messages.join(", "), data: nil)
      end

      private

      def execute_create_task(args)
        taskable = args["record_type"].present? ? find_record!(args["record_type"], args["record_id"]) : nil
        task = @ctx.workspace.tasks.new(
          title: args["title"],
          due_on: args["due_on"],
          taskable: taskable,
          user: @ctx.user,
          assignee: @ctx.user,
          workspace: @ctx.workspace
        )
        authorize!(task, :create?)
        task.save!
        Result.new(success: true, message: "Tarea creada: #{task.title}", data: {id: task.id, title: task.title})
      end

      def execute_add_note(args)
        record = find_record!(args["record_type"], args["record_id"])
        note = record.notes.new(
          workspace: @ctx.workspace,
          user: @ctx.user,
          title: args["title"],
          body: args["body"]
        )
        authorize!(note, :create?)
        note.save!
        Result.new(success: true, message: "Nota añadida en #{record.display_name}", data: {id: note.id})
      end

      def execute_update_record(args)
        record = find_record!(args["record_type"], args["record_id"])
        authorize!(record, :update?)
        fields = args["fields"] || {}
        apply_record_update!(record, fields)
        Result.new(success: true, message: "Registro actualizado: #{record.display_name}", data: {id: record.id})
      end

      def execute_update_deal_stage(args)
        deal = @ctx.workspace.deals.find(args["deal_id"])
        authorize!(deal, :move?)
        deal.move_to_stage!(args["stage"])
        Result.new(success: true, message: "Deal movido a «#{args["stage"]}»", data: {id: deal.id, stage: deal.stage_label})
      end

      def execute_complete_task(args)
        task = @ctx.workspace.tasks.find(args["task_id"])
        authorize!(task, :toggle?)
        task.toggle_completed!
        status = task.completed? ? "completada" : "reabierta"
        Result.new(success: true, message: "Tarea #{status}: #{task.title}", data: {id: task.id, completed: task.completed?})
      end

      def apply_record_update!(record, fields)
        case record
        when Person
          record.update!(pick_fields(fields, "first_name", "last_name", "email", "phone",
            "job_title", "location", "linkedin_url", "description", "company_id"))
        when Company
          record.update!(pick_fields(fields, "name", "domain", "industry", "employee_range",
            "location", "annual_revenue", "description"))
        when Deal
          attrs = pick_fields(fields, "name", "value", "currency", "probability", "expected_close_date", "company_id")
          record.update!(attrs) if attrs.any?
          record.move_to_stage!(fields["stage"]) if fields["stage"].present?
        end
      end

      def pick_fields(fields, *keys)
        keys.index_with { |key| fields[key] }.compact
      end

      def find_record!(type, id)
        Ai::RecordResolver.find!(@ctx.workspace, type, id)
      end

      def authorize!(record, query)
        Pundit.authorize(@ctx, record, query)
      end
    end
  end
end
