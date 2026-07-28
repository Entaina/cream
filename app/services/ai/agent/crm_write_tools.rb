module Ai
  module Agent
    # CRM write tools that only propose actions; execution happens after user confirmation.
    class CrmWriteTools
      RECORD_TYPES = %w[person company deal].freeze

      TOOLS = [
        {
          type: "function",
          name: "create_task",
          description: "Propose creating a task, optionally linked to a person, company or deal. Requires user confirmation.",
          parameters: {
            type: "object",
            properties: {
              title: { type: "string" },
              due_on: { type: "string", description: "ISO date (YYYY-MM-DD)" },
              record_type: { type: "string", enum: RECORD_TYPES },
              record_id: { type: "integer" }
            },
            required: [ "title" ],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "add_note",
          description: "Propose adding a note to a person, company or deal. Requires user confirmation.",
          parameters: {
            type: "object",
            properties: {
              record_type: { type: "string", enum: RECORD_TYPES },
              record_id: { type: "integer" },
              title: { type: "string" },
              body: { type: "string" }
            },
            required: [ "record_type", "record_id", "body" ],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "update_record",
          description: "Propose updating fields on a person, company or deal. Requires user confirmation.",
          parameters: {
            type: "object",
            properties: {
              record_type: { type: "string", enum: RECORD_TYPES },
              record_id: { type: "integer" },
              fields: {
                type: "object",
                description: "Fields to update (e.g. name, email, value, probability, stage, description)"
              }
            },
            required: [ "record_type", "record_id", "fields" ],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "update_deal_stage",
          description: "Propose moving a deal to another stage. Requires user confirmation.",
          parameters: {
            type: "object",
            properties: {
              deal_id: { type: "integer" },
              stage: { type: "string", description: "Target stage name" }
            },
            required: [ "deal_id", "stage" ],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "complete_task",
          description: "Propose marking a task as completed (or reopening it). Requires user confirmation.",
          parameters: {
            type: "object",
            properties: { task_id: { type: "integer" } },
            required: [ "task_id" ],
            additionalProperties: false
          }
        }
      ].freeze

      def initialize(ctx:, pending_actions:, on_status: nil)
        @ctx = ctx
        @pending_actions = pending_actions
        @on_status = on_status
      end

      def definitions
        TOOLS
      end

      def try_execute(name, args)
        case name
        when "create_task" then propose_create_task(args)
        when "add_note" then propose_add_note(args)
        when "update_record" then propose_update_record(args)
        when "update_deal_stage" then propose_update_deal_stage(args)
        when "complete_task" then propose_complete_task(args)
        else nil
        end
      end

      private

      def propose_create_task(args)
        notify("Preparando creación de tarea…")
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
        label = taskable ? " en #{taskable.display_name}" : ""
        propose(
          tool: "create_task",
          args: args,
          description: "Crear tarea «#{args["title"]}»#{label}"
        )
      rescue ActiveRecord::RecordNotFound
        "Record not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def propose_add_note(args)
        notify("Preparando nota en Cream…")
        record = find_record!(args["record_type"], args["record_id"])
        note = record.notes.new(
          workspace: @ctx.workspace,
          user: @ctx.user,
          title: args["title"],
          body: args["body"]
        )
        authorize!(note, :create?)
        propose(
          tool: "add_note",
          args: args,
          description: "Añadir nota en #{record.display_name}"
        )
      rescue ActiveRecord::RecordNotFound
        "Record not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def propose_update_record(args)
        notify("Preparando actualización en Cream…")
        record = find_record!(args["record_type"], args["record_id"])
        authorize!(record, :update?)
        field_names = Array(args.dig("fields")&.keys).join(", ")
        propose(
          tool: "update_record",
          args: args,
          description: "Actualizar #{record.display_name} (#{field_names})"
        )
      rescue ActiveRecord::RecordNotFound
        "Record not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def propose_update_deal_stage(args)
        notify("Preparando cambio de etapa…")
        deal = @ctx.workspace.deals.find(args["deal_id"])
        authorize!(deal, :move?)
        propose(
          tool: "update_deal_stage",
          args: args,
          description: "Mover «#{deal.name}» a etapa «#{args["stage"]}»"
        )
      rescue ActiveRecord::RecordNotFound
        "Deal not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def propose_complete_task(args)
        notify("Preparando completar tarea…")
        task = @ctx.workspace.tasks.find(args["task_id"])
        authorize!(task, :toggle?)
        action = task.completed? ? "Reabrir" : "Completar"
        propose(
          tool: "complete_task",
          args: args,
          description: "#{action} tarea «#{task.title}»"
        )
      rescue ActiveRecord::RecordNotFound
        "Task not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def propose(tool:, args:, description:)
        @pending_actions << PendingAction.new(
          tool: tool,
          args: args,
          description: description,
          workspace_id: @ctx.workspace.id,
          user_id: @ctx.user.id
        )
        "Acción propuesta: #{description}. Pendiente de confirmación del usuario. No se ha ejecutado aún."
      end

      def find_record!(type, id)
        Ai::RecordResolver.find!(@ctx.workspace, type, id)
      end

      def authorize!(record, query)
        Pundit.authorize(@ctx, record, query)
      end

      def forbidden(error)
        "Forbidden: #{error.message}"
      end

      def notify(message)
        @on_status&.call(message)
      end
    end
  end
end
