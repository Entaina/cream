module StageTriggers
  module Native
    class WonCelebration
      def self.call(deal:, user:, trigger:, ui:, params: {})
        message = celebration_message(deal)
        ui.show_toast(message: message, kind: "success")
      end

      def self.celebration_message(deal)
        scope = "stage_triggers.native_handlers.won_celebration"
        if deal.value.to_f.positive?
          I18n.t("#{scope}.message_with_value",
            name: deal.name,
            amount: ApplicationController.helpers.money(deal.value, deal.currency))
        else
          I18n.t("#{scope}.message", name: deal.name)
        end
      end
    end
  end
end
