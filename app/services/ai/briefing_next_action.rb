module Ai
  module BriefingNextAction
    RULES = <<~TEXT.squish
      Next-action rules for deals in open_deals:
      - If has_scheduled_next_action is true: do NOT recommend new parallel actions, do NOT mark the deal inactive or missing a next step.
      - If the scheduled date is far away: at most suggest moving that task earlier (adelantar/reagendar); never a parallel action.
      - When mentioning such a deal, cite next_action (e.g. "próxima acción: llamada el 17 de agosto"), not days_since_last_activity.
      - If missing_next_action is true: flag the gap and recommend defining a next step.
      - If next_action.status is overdue or due_today: the deal needs action today.
    TEXT

    RESCHEDULE_PATTERN = /\b(adelantar|reagendar|anticipar|traer adelante|mover la fecha|adelante la)\b/i

    module_function

    def filter_items(items, open_deals)
      scheduled = scheduled_deals_index(open_deals)
      return items if scheduled.empty?

      items.select { |item| keep_item?(item, scheduled) }
    end

    def scheduled_deals_index(open_deals)
      Array(open_deals).each_with_object({}) do |deal, index|
        data = deal.with_indifferent_access
        next unless data[:has_scheduled_next_action]

        index[data[:id].to_i] = data[:next_action]
      end
    end

    def keep_item?(item, scheduled)
      return true if reschedule_text?(item["text"])

      case item["record_type"].to_s
      when "Deal"
        !scheduled.key?(item["record_id"].to_i)
      when "Task"
        scheduled.none? do |_deal_id, next_action|
          next_action_data = next_action.with_indifferent_access
          next_action_data[:id].to_i == item["record_id"].to_i
        end
      else
        true
      end
    end

    def reschedule_text?(text)
      text.to_s.match?(RESCHEDULE_PATTERN)
    end
  end
end
