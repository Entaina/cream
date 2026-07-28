module StageTriggers
  module Native
    class ShowToast
      def self.call(deal:, user:, trigger:, ui:, params:)
        ui.show_toast(message: params["message"], kind: params["kind"].presence || "info")
      end
    end
  end
end
