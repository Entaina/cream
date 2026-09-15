module Ai
  module Agent
    # Read-only CRM tools scoped with Pundit.
    class CrmReadTools
      RECORD_TYPES = %w[person company deal].freeze

      TOOLS = [
        {
          type: "function",
          name: "search_records",
          description: "Search people, companies and deals by name, email, domain or industry.",
          parameters: {
            type: "object",
            properties: {query: {type: "string", description: "Search text"}},
            required: ["query"],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "get_record",
          description: "Get full CRM details of a person, company or deal including notes, tasks and activity.",
          parameters: {
            type: "object",
            properties: {
              record_type: {type: "string", enum: RECORD_TYPES},
              record_id: {type: "integer"}
            },
            required: ["record_type", "record_id"],
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "list_tasks",
          description: "List pending tasks in the workspace, optionally filtered by status.",
          parameters: {
            type: "object",
            properties: {
              status: {type: "string", enum: %w[pending completed all], description: "Default: pending"}
            },
            additionalProperties: false
          }
        },
        {
          type: "function",
          name: "pipeline_summary",
          description: "Pipeline overview: deal count and total value per stage, plus open/won totals.",
          parameters: {type: "object", properties: {}, additionalProperties: false}
        }
      ].freeze

      def initialize(ctx:, on_status: nil)
        @ctx = ctx
        @on_status = on_status
      end

      def definitions
        TOOLS
      end

      def try_execute(name, args)
        case name
        when "search_records" then execute_search(args)
        when "get_record" then execute_get_record(args)
        when "list_tasks" then execute_list_tasks(args)
        when "pipeline_summary" then execute_pipeline_summary
        end
      end

      private

      def execute_search(args)
        notify("Buscando en Cream…")
        authorize_workspace!(:search?)
        q = args["query"].to_s
        JSON.pretty_generate(
          people: policy_scope(@ctx.workspace.people).search(q).limit(10).map { |p| person_json(p) },
          companies: policy_scope(@ctx.workspace.companies).search(q).limit(10).map { |c| company_json(c) },
          deals: policy_scope(@ctx.workspace.deals).search(q).limit(10).map { |d| deal_json(d) }
        )
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def execute_get_record(args)
        notify("Consultando registro en Cream…")
        record = find_record!(args["record_type"], args["record_id"])
        authorize!(record, :show?)
        JSON.pretty_generate(RecordContextBuilder.new(record: record, user: @ctx.user).to_h)
      rescue ActiveRecord::RecordNotFound
        "Record not found."
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def execute_list_tasks(args)
        notify("Listando tareas en Cream…")
        authorize_workspace!(:search?)
        scope = policy_scope(@ctx.workspace.tasks)
        scope = case args["status"].to_s
        when "completed" then scope.completed
        when "all" then scope
        else scope.pending
        end
        JSON.pretty_generate(scope.due_order.limit(25).map { |t| task_json(t) })
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def execute_pipeline_summary
        notify("Consultando pipeline en Cream…")
        authorize_workspace!(:dashboard?)
        ws = @ctx.workspace
        deals = policy_scope(ws.deals)
        tasks = policy_scope(ws.tasks)
        counts = deals.group(:pipeline_stage_id).count
        values = deals.group(:pipeline_stage_id).sum(:value)
        stages = ws.pipeline_stages.ordered.to_h do |stage|
          [stage.name, {
            count: counts[stage.id] || 0,
            total_value: (values[stage.id] || 0).to_f,
            probability: stage.probability
          }]
        end
        JSON.pretty_generate(
          stages: stages,
          open_pipeline_value: deals.open_deals.sum(:value).to_f,
          won_value: deals.won.sum(:value).to_f,
          pending_tasks: tasks.pending.count
        )
      rescue Pundit::NotAuthorizedError => e
        forbidden(e)
      end

      def find_record!(type, id)
        Ai::RecordResolver.find!(@ctx.workspace, type, id)
      end

      def policy_scope(scope)
        Pundit.policy_scope(@ctx, scope)
      end

      def authorize!(record, query)
        Pundit.authorize(@ctx, record, query)
      end

      def authorize_workspace!(query)
        Pundit.authorize(@ctx, @ctx.workspace, query)
      end

      def person_json(person)
        {id: person.id, type: "person", name: person.display_name, email: person.email,
         company: person.company&.name}.compact
      end

      def company_json(company)
        {id: company.id, type: "company", name: company.name, domain: company.domain,
         industry: company.industry}.compact
      end

      def deal_json(deal)
        {id: deal.id, type: "deal", name: deal.name, stage: deal.stage_label,
         value: deal.value.to_f, company: deal.company&.name}.compact
      end

      def task_json(task)
        {id: task.id, title: task.title, due_on: task.due_on&.iso8601,
         completed: task.completed?, record: task.taskable&.display_name}.compact
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
