module StageTriggers
  # Developer-maintained catalogue of native trigger handlers. Registering a
  # function here makes it selectable in the stage trigger form, so frequently
  # used LLM triggers can be ported to plain Ruby without touching delivery.
  #
  # Functions can declare params: the trigger form renders one field per param
  # (type "string" | "text" | "select"), the values are stored in the
  # trigger's native_params jsonb and passed to the handler as `params:`.
  module NativeRegistry
    Param = Data.define(:key, :label, :type, :required, :placeholder, :options) do
      def initialize(key:, label:, type: "string", required: false, placeholder: nil, options: nil)
        super
      end
    end

    Entry = Data.define(:key, :label, :description, :handler, :params) do
      def initialize(key:, label:, description:, handler:, params: [])
        super
      end
    end

    FUNCTIONS = {
      "show_toast" => Entry.new(
        key: "show_toast",
        label: "Mostrar toast",
        description: "Muestra una notificación breve con el texto configurado.",
        handler: "StageTriggers::Native::ShowToast",
        params: [
          Param.new(key: "message", label: "Texto", type: "text", required: true,
            placeholder: "Ej.: Recuerda pedir el NIF en esta etapa"),
          Param.new(key: "kind", label: "Estilo", type: "select",
            options: [["Información", "info"], ["Éxito", "success"], ["Aviso", "warning"]])
        ]
      ),
      "won_celebration" => Entry.new(
        key: "won_celebration",
        label: "Celebración de deal ganado",
        description: "Muestra un toast de felicitación con el nombre y el valor del deal.",
        handler: "StageTriggers::Native::WonCelebration"
      ),
      "stage_checklist_panel" => Entry.new(
        key: "stage_checklist_panel",
        label: "Checklist de la etapa en el deal",
        description: "Muestra un panel en el deal recordando los siguientes pasos de la etapa.",
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
