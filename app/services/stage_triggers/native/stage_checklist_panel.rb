module StageTriggers
  module Native
    class StageChecklistPanel
      SCOPE = "stage_triggers.native_handlers.stage_checklist_panel"

      def self.call(deal:, user:, trigger:, ui:, params: {})
        stage = deal.pipeline_stage
        pending = deal.tasks.pending.order(:due_on).limit(5)
        lines = [I18n.t("#{SCOPE}.entered_stage", stage: stage.name)]
        lines << ""
        if pending.any?
          lines << I18n.t("#{SCOPE}.pending_tasks")
          pending.each do |task|
            lines << if task.due_on
              I18n.t("#{SCOPE}.task_due", title: task.title, date: I18n.l(task.due_on, format: :short))
            else
              I18n.t("#{SCOPE}.task_item", title: task.title)
            end
          end
        else
          lines << I18n.t("#{SCOPE}.no_pending_tasks")
        end
        ui.show_deal_panel(title: I18n.t("#{SCOPE}.title", stage: stage.name), markdown: lines.join("\n"))
      end
    end
  end
end
