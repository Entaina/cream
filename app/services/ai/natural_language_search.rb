module Ai
  # Phase 2: deterministic natural-language search without embeddings.
  class NaturalLanguageSearch
    Result = Data.define(:interpretation, :people, :companies, :deals, :tasks, :emails, :open_deal_tasks)
    TASK_WORD = /\b(tarea|tareas|task|tasks)\b/
    PERSONAL_WORD = /\b(mis|my|m[ií]s)\b/
    OVERDUE_WORD = /\b(atrasad[ao]s?|vencid[ao]s?|overdue)\b/
    TODAY_WORD = /\b(hoy|today|para hoy)\b/
    STALLED_DEAL_LIMIT = 100

    def initialize(workspace:, query:, people_scope:, companies_scope:, deals_scope:, tasks_scope: nil, user: nil)
      @workspace = workspace
      @query = query.to_s.strip
      @people_scope = people_scope
      @companies_scope = companies_scope
      @deals_scope = deals_scope
      @tasks_scope = tasks_scope || workspace.tasks
      @user = user
    end

    def call
      normalized = @query.downcase

      return today_or_overdue_tasks(assignee: @user) if my_tasks_today_or_overdue?(normalized)
      return today_or_overdue_tasks(assignee: personal_assignee(normalized)) if task_today_or_overdue?(normalized)
      return due_today_tasks(assignee: personal_assignee(normalized)) if task_due_today?(normalized)
      return overdue_tasks(assignee: personal_assignee(normalized)) if overdue_task_query?(normalized)
      return today_or_overdue_tasks(assignee: @user) if my_tasks_query?(normalized)

      entity_tasks = tasks_for_named_entity(normalized)
      return entity_tasks if entity_tasks

      case normalized
      when /\b(stalled|stuck|parad[oa]s?)\b.*\bdeal/
        stalled_deals
      when /\bdeal\b.*\b(stalled|stuck|parad[oa]s?)\b/
        stalled_deals
      when /\boverdue\b.*\btask/
        overdue_tasks
      when /\bfollow.?up\b/
        pending_follow_ups
      when /\b(won|closed won|ganad[oa]s?)\b/
        won_deals
      when /\b(no contact|sin contacto|inactive)\b/
        inactive_records
      else
        default_search
      end
    end

    private

    def result(interpretation:, people: [], companies: [], deals: [], tasks: [], emails: [], open_deal_tasks: [])
      Result.new(interpretation, people, companies, deals, tasks, emails, open_deal_tasks)
    end

    def personal_assignee(normalized)
      @user if normalized.match?(PERSONAL_WORD)
    end

    def my_tasks_query?(normalized)
      normalized.match?(PERSONAL_WORD) && normalized.match?(TASK_WORD)
    end

    def my_tasks_today_or_overdue?(normalized)
      my_tasks_query?(normalized) && (normalized.match?(OVERDUE_WORD) || normalized.match?(TODAY_WORD))
    end

    def task_today_or_overdue?(normalized)
      normalized.match?(TASK_WORD) && normalized.match?(OVERDUE_WORD) && normalized.match?(TODAY_WORD)
    end

    def task_due_today?(normalized)
      normalized.match?(TASK_WORD) && normalized.match?(TODAY_WORD)
    end

    def overdue_task_query?(normalized)
      normalized.match?(TASK_WORD) && normalized.match?(OVERDUE_WORD)
    end

    def tasks_for_named_entity(normalized)
      return nil unless normalized.match?(TASK_WORD)

      if (match = normalized.match(/\b(tareas?|tasks?)\b.*\b(asignadas?\s+a|assigned\s+to)\s+(.+)/))
        return tasks_for_assignee_query(match[3].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\s+de\s+(usuario|user)\s+(.+)/))
        return tasks_for_assignee_query(match[3].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\b.*\b(empresa|company)\b.*\b(de|del|named?|called)?\s*(.+)/))
        return tasks_for_record_query("company", match[4].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\s+de\s+la\s+empresa\s+(.+)/))
        return tasks_for_record_query("company", match[2].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\b.*\b(contacto|persona|person|contact)\b.*\b(de|del)?\s*(.+)/))
        return tasks_for_record_query("person", match[4].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\s+del\s+contacto\s+(.+)/))
        return tasks_for_record_query("person", match[2].strip)
      end

      if (match = normalized.match(/\b(tareas?|tasks?)\s+de\s+(.+)/)) && !normalized.match?(PERSONAL_WORD)
        name = match[2].strip
        return nil if name.blank? || name.match?(OVERDUE_WORD) || name.match?(TODAY_WORD)

        return tasks_for_record_query("company", name) ||
            tasks_for_record_query("person", name) ||
            tasks_for_assignee_query(name)
      end

      nil
    end

    def tasks_for_record_query(type, query)
      scope = case type
      when "company" then @companies_scope.search(query)
      when "person" then @people_scope.search(query)
      else return nil
      end
      count = scope.count
      return nil if count != 1

      record = scope.first
      tasks_for_record(record, interpretation: "Tasks linked to #{type} '#{record.display_name}'")
    end

    def tasks_for_assignee_query(query)
      q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope = @workspace.users.where("users.name ILIKE :q OR users.email_address ILIKE :q", q: q)
      count = scope.count
      return nil if count != 1

      assignee = scope.first
      tasks_for_assignee(assignee)
    end

    def tasks_for_record(record, interpretation:)
      direct = @tasks_scope.includes(:taskable, :assignee).where(taskable: record).due_order.limit(25).to_a
      result(
        interpretation: interpretation,
        tasks: direct,
        open_deal_tasks: grouped_open_deal_tasks(record)
      )
    end

    def grouped_open_deal_tasks(record)
      open_deals = case record
      when Company
        @deals_scope.where(company_id: record.id).open_deals.order(:name).to_a
      when Person
        @deals_scope.joins(:contacts).where(people: {id: record.id}).open_deals.distinct.order(:name).to_a
      else
        []
      end
      return [] if open_deals.empty?

      deal_ids = open_deals.map(&:id)
      tasks_by_deal = @tasks_scope.includes(:taskable, :assignee)
        .where(taskable_type: "Deal", taskable_id: deal_ids)
        .due_order
        .group_by(&:taskable_id)
      remaining = 25

      open_deals.filter_map do |deal|
        next if remaining <= 0

        tasks = (tasks_by_deal[deal.id] || []).first(remaining)
        remaining -= tasks.size
        next if tasks.empty?

        {deal: deal, tasks: tasks}
      end
    end

    def tasks_for_assignee(assignee)
      tasks = @tasks_scope.includes(:taskable, :assignee).where(assignee: assignee).due_order.limit(25).to_a
      result(
        interpretation: "Tasks assigned to #{assignee.name}",
        tasks: tasks
      )
    end

    def stalled_deals
      deals = @deals_scope.includes(:company, :pipeline_stage).joins(:pipeline_stage)
        .where(pipeline_stages: {closed: false})
        .limit(STALLED_DEAL_LIMIT)
        .select { |deal| deal.magic_column_value(:days_in_stage).to_i >= 7 }

      result(
        interpretation: "Open deals that have been in the current stage for 7+ days",
        deals: deals.first(25)
      )
    end

    def overdue_tasks(assignee: nil)
      scope = @tasks_scope.pending.overdue.includes(:taskable, :assignee).due_order
      scope = scope.where(assignee: assignee) if assignee

      result(
        interpretation: "Pending tasks past their due date",
        tasks: scope.limit(25).to_a
      )
    end

    def due_today_tasks(assignee: nil)
      scope = @tasks_scope.pending.due_today.includes(:taskable, :assignee).due_order
      scope = scope.where(assignee: assignee) if assignee

      result(
        interpretation: "Pending tasks due today",
        tasks: scope.limit(25).to_a
      )
    end

    def today_or_overdue_tasks(assignee: nil)
      scope = @tasks_scope.pending.due_today_or_overdue.includes(:taskable, :assignee).due_order
      scope = scope.where(assignee: assignee) if assignee

      result(
        interpretation: "Pending tasks due today or past their due date",
        tasks: scope.limit(25).to_a
      )
    end

    def pending_follow_ups
      emails = @workspace.email_messages.includes(:record).recent_first
        .where("follow_up_at IS NOT NULL AND replied_at IS NULL AND status != 'scheduled' AND direction = 'outbound'")
        .limit(25)
        .to_a

      result(
        interpretation: "Sent emails with a pending follow-up reminder",
        emails: emails
      )
    end

    def won_deals
      deals = @deals_scope.won.includes(:company).limit(25)

      result(
        interpretation: "Deals in a won stage",
        deals: deals.to_a
      )
    end

    def inactive_records
      cutoff = 14.days.ago
      people = @people_scope.left_joins(:activities)
        .group("people.id")
        .having("MAX(activities.created_at) < ? OR MAX(activities.created_at) IS NULL", cutoff)
        .limit(25)
        .to_a
      companies = @companies_scope.left_joins(:activities)
        .group("companies.id")
        .having("MAX(activities.created_at) < ? OR MAX(activities.created_at) IS NULL", cutoff)
        .limit(25)
        .to_a

      result(
        interpretation: "Records with no activity in the last 14 days",
        people: people,
        companies: companies
      )
    end

    def default_search
      result(
        interpretation: "Keyword search across people, companies and deals",
        people: @people_scope.search(@query).includes(:company).limit(8).to_a,
        companies: @companies_scope.search(@query).limit(8).to_a,
        deals: @deals_scope.search(@query).includes(:company).limit(8).to_a
      )
    end
  end
end
