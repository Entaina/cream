module Ai
  class PersonalSalesDirector
    SYSTEM = <<~TEXT.squish
      You are the sales director speaking directly to one salesperson. Analyze their recent
      performance and pipeline and give them a personal daily briefing. Respond ONLY with valid JSON:
      summary (string, 1-2 sentences addressed to them in second person),
      items (array with keys: priority, text, record_type, record_id),
      wins (array of strings celebrating concrete recent achievements),
      misses (array of strings describing mistakes or gaps with a brief recommendation).
      priority must be one of: urgent, important.
      record_type must be one of: Deal, Person, Company, Task, or null.
      Use record_id from context when referencing a record.
      Ground everything in the provided context. Prefer 2-5 items, 1-3 wins, 1-3 misses.
      Write in Spanish, tutea al comercial, sé directo pero constructivo.
      #{BriefingNextAction::RULES}
    TEXT

    OPEN_DEAL_LIMIT = 25
    TASK_LIMIT = 15
    RECENT_DAYS = 14

    def initialize(workspace:, user:, briefing_date: Date.current, client: Client.new, drive: nil)
      @workspace = workspace
      @user = user
      @briefing_date = briefing_date
      @client = client
      @drive = drive
    end

    def call
      return nil unless Configuration.configured?

      research = research_notes
      raw = @client.chat(
        system: SYSTEM,
        user: briefing_prompt(research),
        json: true
      )
      payload = normalize(JsonParser.parse(raw))
      briefing = upsert_briefing(payload)
      record_briefing_memory(briefing)
      briefing
    end

    private

    def research_notes
      SalesDirectorResearch.new(
        workspace: @workspace,
        user: @user,
        briefing_date: @briefing_date,
        prefetch_terms: prefetch_terms,
        drive: @drive
      ).call
    end

    def prefetch_terms
      Array(context.to_h[:open_deals]).filter_map { |deal| deal[:company] || deal["company"] }.uniq.first(3)
    end

    def briefing_prompt(research)
      prompt = "Produce today's personal sales briefing for this user:\n\n#{context.to_prompt}"
      prompt += "\n\n## Investigación OKM, CRM y memoria\n#{research}" if research.present?
      prompt
    end

    def record_briefing_memory(briefing)
      memory = AgentMemory.new(
        workspace: @workspace,
        user: @user,
        session_id: "briefing:#{@briefing_date}"
      )
      memory.record_turn(
        user_message: "Generar briefing personal para #{@briefing_date}",
        assistant_message: briefing.summary.to_s
      )
      memory.consolidate_later
    rescue => e
      Rails.logger.warn("[PersonalSalesDirector] memory: #{e.class}: #{e.message}")
    end

    def context
      @context ||= UserContextBuilder.new(
        workspace: @workspace,
        user: @user,
        briefing_date: @briefing_date
      )
    end

    def normalize(payload)
      {
        summary: payload["summary"].to_s.strip,
        items: normalize_items(payload["items"]),
        wins: normalize_strings(payload["wins"]),
        misses: normalize_strings(payload["misses"])
      }
    end

    def normalize_items(raw_items)
      Array(raw_items).filter_map do |item|
        next if item.blank?

        priority = item["priority"].to_s
        next unless SalesBriefing::PRIORITIES.include?(priority)

        text = item["text"].to_s.strip
        next if text.blank?

        normalized = {"priority" => priority, "text" => text}
        record_type = item["record_type"].to_s.presence
        if record_type.in?(SalesBriefing::RECORD_TYPES)
          normalized["record_type"] = record_type
          normalized["record_id"] = item["record_id"].to_i if item["record_id"].present?
        end
        normalized.compact
      end.then { |items| BriefingNextAction.filter_items(items, context.to_h[:open_deals]) }
    end

    def normalize_strings(values)
      Array(values).filter_map { |value| value.to_s.strip.presence }
    end

    def upsert_briefing(payload)
      briefing = @workspace.sales_briefings.personal_for(@user).find_or_initialize_by(briefing_date: @briefing_date)
      briefing.assign_attributes(
        summary: payload[:summary],
        items: payload[:items],
        wins: payload[:wins],
        misses: payload[:misses],
        generated_at: Time.current
      )
      briefing.save!
      briefing
    end

    class UserContextBuilder
      def initialize(workspace:, user:, briefing_date:)
        @workspace = workspace
        @user = user
        @briefing_date = briefing_date
        @cutoff = briefing_date - RECENT_DAYS.days
      end

      def to_h
        {
          workspace: @workspace.name,
          briefing_date: @briefing_date.iso8601,
          user: {id: @user.id, name: @user.name},
          open_deals: open_deals,
          overdue_tasks: overdue_tasks,
          pending_tasks: pending_tasks,
          completed_tasks: completed_tasks,
          recent_closed_deals: recent_closed_deals,
          stage_changes: stage_changes
        }
      end

      def to_prompt
        JSON.pretty_generate(to_h)
      end

      private

      def open_deals
        @workspace.deals.open_deals.where(owner: @user)
          .includes(:pipeline, :pipeline_stage, :owner, :company, :tasks)
          .order(value: :desc, id: :asc)
          .limit(OPEN_DEAL_LIMIT)
          .map { |deal| SalesSnapshots.deal_snapshot(deal, briefing_date: @briefing_date) }
      end

      def overdue_tasks
        assigned_tasks.pending
          .where("due_on < ?", @briefing_date)
          .due_order
          .limit(TASK_LIMIT)
          .map { |task| SalesSnapshots.task_snapshot(task) }
      end

      def pending_tasks
        assigned_tasks.pending
          .where("due_on IS NULL OR due_on >= ?", @briefing_date)
          .due_order
          .limit(TASK_LIMIT)
          .map { |task| SalesSnapshots.task_snapshot(task) }
      end

      def completed_tasks
        assigned_tasks.completed
          .where(completed_at: @cutoff.beginning_of_day..)
          .order(completed_at: :desc)
          .limit(TASK_LIMIT)
          .map { |task|
            snapshot = SalesSnapshots.task_snapshot(task)
            snapshot[:completed_at] = task.completed_at.iso8601
            snapshot[:completed_on_time] = task.due_on.blank? || task.completed_at.to_date <= task.due_on
            snapshot
          }
      end

      def recent_closed_deals
        @workspace.deals.joins(:pipeline_stage).where(owner: @user, pipeline_stages: {closed: true})
          .includes(:pipeline_stage, :owner)
          .where("deals.updated_at >= ?", @cutoff.beginning_of_day)
          .order(updated_at: :desc)
          .limit(10)
          .map { |deal| SalesSnapshots.closed_deal_snapshot(deal) }
      end

      def stage_changes
        @workspace.activities
          .where(user: @user, action: "stage_changed", subject_type: "Deal")
          .where(created_at: @cutoff.beginning_of_day..)
          .includes(:subject)
          .recent_first
          .limit(15)
          .map { |activity|
            {
              deal_id: activity.subject_id,
              deal_name: activity.subject&.display_name,
              from: activity.metadata["from"],
              to: activity.metadata["to"],
              at: activity.created_at.iso8601
            }.compact
          }
      end

      def assigned_tasks
        @workspace.tasks.where(assignee: @user).includes(:assignee, :taskable)
      end
    end
  end
end
