module StageTriggers
  module Native
    class StageChecklistPanel
      def self.call(deal:, user:, trigger:, ui:, params: {})
        stage = deal.pipeline_stage
        pending = deal.tasks.pending.order(:due_on).limit(5)
        lines = [ "El deal acaba de entrar en **#{stage.name}**." ]
        if pending.any?
          lines << ""
          lines << "Tareas pendientes:"
          pending.each { |task| lines << "- #{task.title}#{" (vence #{task.due_on.strftime("%d/%m/%Y")})" if task.due_on}" }
        else
          lines << ""
          lines << "No hay tareas pendientes. Considera crear la siguiente acción."
        end
        ui.show_deal_panel(title: "Checklist — #{stage.name}", markdown: lines.join("\n"))
      end
    end
  end
end
