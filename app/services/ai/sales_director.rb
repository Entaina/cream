module Ai
  class SalesDirector
    SYSTEM = <<~TEXT.squish
      You are the sales director for a CRM team. Analyze pipeline health daily and tell the team
      what to do today. Respond ONLY with valid JSON with keys:
      summary (string, 1-3 sentences on overall pipeline state),
      items (array of objects with keys: priority, text, record_type, record_id, owner_id).
      priority must be one of: urgent, important.
      urgent = needs action today (overdue close dates, stalled high-value deals, overdue tasks).
      important = strategic follow-ups that should not slip this week.
      record_type must be one of: Deal, Person, Company, Task, or null.
      record_id and owner_id must be numeric ids from the context, or null.
      Ground every item in the provided context. Prefer 3-8 items total, balanced across priorities.
      Write item text in Spanish, concise and actionable.
      #{BriefingNextAction::RULES}
    TEXT

    OPEN_DEAL_LIMIT = 40
    TASK_LIMIT = 20
    RECENT_CLOSED_LIMIT = 10

    def initialize(workspace:, briefing_date: Date.current, client: Client.new, drive: nil)
      @workspace = workspace
      @briefing_date = briefing_date
      @client = client
      @drive = drive
    end

    def call
      return nil unless Configuration.configured?

      actor = @workspace.briefing_actor
      research = research_notes(actor)
      raw = @client.chat(
        system: SYSTEM,
        user: briefing_prompt(research),
        json: true
      )
      payload = normalize(JsonParser.parse(raw))
      briefing = upsert_briefing(payload)
      record_briefing_memory(actor, briefing)
      briefing
    end

    private

    def research_notes(actor)
      return "" unless actor

      SalesDirectorResearch.new(
        workspace: @workspace,
        user: actor,
        briefing_date: @briefing_date,
        prefetch_terms: prefetch_terms,
        memory_scope: AgentMemory::TEAM_SCOPE,
        drive: @drive
      ).call
    end

    def prefetch_terms
      Array(context.to_h[:open_deals]).filter_map { |deal| deal[:company] || deal["company"] }.uniq.first(3)
    end

    def briefing_prompt(research)
      prompt = "Analyze this workspace and produce today's sales briefing:\n\n#{context.to_prompt}"
      prompt += "\n\n## Investigación OKM, CRM y memoria\n#{research}" if research.present?
      prompt
    end

    def record_briefing_memory(actor, briefing)
      memory = AgentMemory.new(
        workspace: @workspace,
        user: actor,
        session_id: "briefing:#{@briefing_date}",
        memory_scope: AgentMemory::TEAM_SCOPE
      )
      memory.record_turn(
        user_message: "Generar briefing del equipo para #{@briefing_date}",
        assistant_message: briefing.summary.to_s
      )
      memory.consolidate_later
    rescue => e
      Rails.logger.warn("[SalesDirector] memory: #{e.class}: #{e.message}")
    end

    def context
      @context ||= WorkspaceContextBuilder.new(workspace: @workspace, briefing_date: @briefing_date)
    end

    def normalize(payload)
      items = Array(payload["items"]).filter_map do |item|
        next if item.blank?

        priority = item["priority"].to_s
        next unless SalesBriefing::PRIORITIES.include?(priority)

        text = item["text"].to_s.strip
        next if text.blank?

        normalized = {
          "priority" => priority,
          "text" => text
        }

        record_type = item["record_type"].to_s.presence
        if record_type.in?(SalesBriefing::RECORD_TYPES)
          normalized["record_type"] = record_type
          normalized["record_id"] = item["record_id"].to_i if item["record_id"].present?
        end

        normalized["owner_id"] = item["owner_id"].to_i if item["owner_id"].present?
        normalized.compact
      end

      {
        summary: payload["summary"].to_s.strip,
        items: BriefingNextAction.filter_items(items, context.to_h[:open_deals])
      }
    end

    def upsert_briefing(payload)
      briefing = @workspace.sales_briefings.team.find_or_initialize_by(briefing_date: @briefing_date)
      briefing.assign_attributes(
        summary: payload[:summary],
        items: payload[:items],
        wins: [],
        misses: [],
        generated_at: Time.current
      )
      briefing.save!
      briefing
    end

    class WorkspaceContextBuilder
      def initialize(workspace:, briefing_date:)
        @workspace = workspace
        @briefing_date = briefing_date
      end

      def to_h
        {
          workspace: @workspace.name,
          briefing_date: @briefing_date.iso8601,
          team: team_members,
          pipelines: pipeline_summary,
          open_deals: open_deals,
          overdue_tasks: overdue_tasks,
          pending_tasks: pending_tasks,
          recent_closed_deals: recent_closed_deals
        }
      end

      def to_prompt
        JSON.pretty_generate(to_h)
      end

      private

      def team_members
        @workspace.users.map { |user| {id: user.id, name: user.name} }
      end

      def pipeline_summary
        @workspace.pipelines.ordered.includes(:pipeline_stages).map do |pipeline|
          {
            id: pipeline.id,
            name: pipeline.name,
            stages: pipeline.pipeline_stages.ordered.map { |stage|
              {
                id: stage.id,
                name: stage.name,
                closed: stage.closed?,
                won: stage.won?,
                open_deals_count: @workspace.deals.open_deals.where(pipeline_stage_id: stage.id).count
              }
            }
          }
        end
      end

      def open_deals
        @workspace.deals.open_deals
          .includes(:pipeline, :pipeline_stage, :owner, :company, :tasks)
          .order(value: :desc, id: :asc)
          .limit(OPEN_DEAL_LIMIT)
          .map { |deal| SalesSnapshots.deal_snapshot(deal, briefing_date: @briefing_date) }
      end

      def overdue_tasks
        @workspace.tasks.pending.includes(:assignee, :taskable)
          .where("due_on < ?", @briefing_date)
          .due_order
          .limit(TASK_LIMIT)
          .map { |task| SalesSnapshots.task_snapshot(task) }
      end

      def pending_tasks
        @workspace.tasks.pending.includes(:assignee, :taskable)
          .where("due_on IS NULL OR due_on >= ?", @briefing_date)
          .due_order
          .limit(TASK_LIMIT)
          .map { |task| SalesSnapshots.task_snapshot(task) }
      end

      def recent_closed_deals
        cutoff = @briefing_date - 7.days
        @workspace.deals.joins(:pipeline_stage).where(pipeline_stages: {closed: true})
          .includes(:pipeline_stage, :owner)
          .where("deals.updated_at >= ?", cutoff.beginning_of_day)
          .order(updated_at: :desc)
          .limit(RECENT_CLOSED_LIMIT)
          .map { |deal| SalesSnapshots.closed_deal_snapshot(deal) }
      end
    end
  end
end
