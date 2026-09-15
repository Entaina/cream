module Ai
  # Assembles a compact, workspace-scoped context hash for LLM prompts.
  class RecordContextBuilder
    LIMITS = {
      notes: 8,
      comments: 8,
      emails: 5,
      tasks: 10,
      activities: 12
    }.freeze

    def initialize(record:, user: nil)
      @record = record
      @user = user
    end

    def to_h
      base = {
        record_type: @record.class.name,
        record_id: @record.id,
        name: @record.display_name,
        workspace: @record.workspace.name,
        owner: @record.owner&.name,
        custom_fields: @record.custom_fields_hash.compact.presence
      }.compact

      base.merge(type_specific).merge(related_content).merge(signals)
    end

    def to_prompt
      JSON.pretty_generate(to_h)
    end

    private

    def type_specific
      case @record
      when Person
        {
          email: @record.email,
          phone: @record.phone,
          job_title: @record.job_title,
          location: @record.location,
          company: @record.company&.name,
          description: @record.description,
          linkedin_url: @record.linkedin_url
        }.compact
      when Company
        {
          domain: @record.domain,
          industry: @record.industry,
          employee_range: @record.employee_range,
          location: @record.location,
          annual_revenue: @record.annual_revenue,
          description: @record.description,
          people_count: @record.people.size,
          open_deals_count: @record.deals.joins(:pipeline_stage).where(pipeline_stages: {closed: false}).count
        }.compact
      when Deal
        {
          value: @record.value.to_f,
          currency: @record.currency,
          stage: @record.stage_label,
          pipeline: @record.pipeline&.name,
          probability: @record.probability,
          expected_close_date: @record.expected_close_date&.iso8601,
          company: @record.company&.name,
          contacts: @record.contacts.map(&:display_name),
          products: @record.deal_products.includes(:product).map { |line|
            {name: line.product.name, quantity: line.quantity, subtotal: line.subtotal.to_f}
          }.presence
        }.compact
      else
        {}
      end
    end

    def related_content
      {
        notes: @record.notes.includes(:user).order(created_at: :desc).limit(LIMITS[:notes]).map { |note|
          {title: note.title, body: truncate(note.body), author: note.user.name, at: note.created_at.iso8601}.compact
        },
        comments: @record.comments.includes(:user).top_level.recent_first.limit(LIMITS[:comments]).map { |comment|
          {body: truncate(comment.body), author: comment.user.name, at: comment.created_at.iso8601}
        },
        emails: @record.email_messages.recent_first.limit(LIMITS[:emails]).map { |message|
          {
            subject: message.subject,
            to: message.to_address,
            status: message.status,
            opened: message.opened?,
            replied: message.replied?,
            awaiting_follow_up: message.awaiting_follow_up?,
            body: truncate(message.body),
            at: message.created_at.iso8601
          }.compact
        },
        tasks: @record.tasks.due_order.limit(LIMITS[:tasks]).map { |task|
          {
            title: task.title,
            due_on: task.due_on&.iso8601,
            completed: task.completed?,
            overdue: task.overdue?,
            assignee: task.assignee&.name
          }.compact
        },
        recent_activity: @record.activities.includes(:user).recent_first.limit(LIMITS[:activities]).map { |activity|
          {
            action: activity.action,
            by: activity.user&.name,
            at: activity.created_at.iso8601,
            details: activity.metadata.presence
          }.compact
        }
      }
    end

    def signals
      signals = {
        open_tasks: @record.tasks.pending.count,
        overdue_tasks: @record.tasks.pending.count { |task| task.overdue? },
        notes_count: @record.notes.count,
        last_activity_at: @record.magic_column_value(:last_activity_at)&.iso8601
      }

      if @record.is_a?(Deal)
        signals[:days_in_stage] = @record.magic_column_value(:days_in_stage)
        signals[:close_date_overdue] = @record.expected_close_date.present? && @record.expected_close_date < Date.current
        signals[:awaiting_email_follow_up] = @record.email_messages.any?(&:awaiting_follow_up?)
      end

      signals.compact
    end

    def truncate(text, length: 500)
      text.to_s.truncate(length)
    end
  end
end
