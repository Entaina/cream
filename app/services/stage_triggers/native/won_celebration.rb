module StageTriggers
  module Native
    class WonCelebration
      def self.call(deal:, user:, trigger:, ui:, params: {})
        message = "🎉 ¡Enhorabuena! «#{deal.name}» ganado"
        message += " (#{ActiveSupport::NumberHelper.number_to_currency(deal.value, unit: "€", format: "%n %u")})" if deal.value.to_f.positive?
        ui.show_toast(message: message, kind: "success")
      end
    end
  end
end
