module StageTriggers
  # Developer-maintained catalogue of native trigger handlers. Registering a
  # function here makes it selectable in the stage trigger form, so frequently
  # used LLM triggers can be ported to plain Ruby without touching delivery.
  #
  # Functions can declare params: the trigger form renders one field per param
  # (type "string" | "text" | "select"), the values are stored in the
  # trigger's native_params jsonb and passed to the handler as `params:`.
  module NativeRegistry
    Param = Data.define(:function_key, :key, :type, :required, :select_values) do
      def initialize(function_key:, key:, type: "string", required: false, select_values: nil)
        super
      end

      def label
        I18n.t("stage_triggers.native_functions.#{function_key}.params.#{key}.label")
      end

      def placeholder
        I18n.t("stage_triggers.native_functions.#{function_key}.params.#{key}.placeholder", default: "")
      end

      def options
        return nil unless select_values

        select_values.map do |value|
          [I18n.t("stage_triggers.native_functions.#{function_key}.params.#{key}.options.#{value}"), value]
        end
      end
    end

    Entry = Data.define(:key, :handler, :params) do
      def initialize(key:, handler:, params: [])
        super
      end

      def label
        I18n.t("stage_triggers.native_functions.#{key}.label")
      end

      def description
        I18n.t("stage_triggers.native_functions.#{key}.description")
      end
    end

    FUNCTIONS = {
      "show_toast" => Entry.new(
        key: "show_toast",
        handler: "StageTriggers::Native::ShowToast",
        params: [
          Param.new(function_key: "show_toast", key: "message", type: "text", required: true),
          Param.new(function_key: "show_toast", key: "kind", type: "select",
            select_values: %w[info success warning])
        ]
      ),
      "won_celebration" => Entry.new(
        key: "won_celebration",
        handler: "StageTriggers::Native::WonCelebration"
      ),
      "stage_checklist_panel" => Entry.new(
        key: "stage_checklist_panel",
        handler: "StageTriggers::Native::StageChecklistPanel"
      )
    }.freeze

    def self.keys = FUNCTIONS.keys
    def self.key?(key) = FUNCTIONS.key?(key)
    def self.entries = FUNCTIONS.values
    def self.fetch(key) = FUNCTIONS.fetch(key)
    def self.handler_for(key) = fetch(key).handler.constantize
  end
end
