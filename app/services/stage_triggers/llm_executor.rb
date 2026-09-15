module StageTriggers
  # Runs a natural-language trigger through the LLM with a constrained tool
  # catalogue: read-only CRM context tools plus UI actions delegated to the
  # UiEmitter. No write tools are exposed, so the agent cannot mutate data.
  class LlmExecutor
    UI_TOOLS = %w[show_toast show_alert show_confirm show_deal_panel].freeze

    def initialize(trigger:, deal:, user:, ui:, run:, client: Ai::Client.new)
      @trigger = trigger
      @deal = deal
      @user = user
      @ui = ui
      @run = run
      @client = client
    end

    def call
      final = @client.chat_with_tools(system: system_prompt, input: input_prompt, tools: tool_definitions) do |name, args|
        execute_tool(name, args)
      end
      append_transcript("type" => "assistant", "content" => final) if final.present?
      final
    end

    private

    def system_prompt
      <<~PROMPT
        Eres un asistente dentro del CRM Cream. Un deal acaba de cambiar de etapa y debes
        ejecutar la instrucción configurada por el equipo para esa etapa.

        Dispones de herramientas de consulta (solo lectura) para conocer el deal, su empresa
        y sus contactos, y de herramientas de UI para comunicarte con el usuario en su
        navegador (toast, alert, confirm y un panel dentro del deal).

        Reglas:
        - Comunica siempre el resultado mediante las herramientas de UI, no como texto libre.
        - Usa el idioma en el que esté escrita la instrucción.
        - Sé breve: un toast para avisos cortos, el panel del deal para contenido largo (admite markdown).
        - No inventes datos: consulta el contexto del deal antes de afirmar algo sobre él.
        - Cuando termines, responde con una frase resumiendo qué has hecho.
      PROMPT
    end

    def input_prompt
      <<~INPUT
        El deal «#{@deal.name}» (id #{@deal.id}) acaba de moverse a la etapa «#{@deal.pipeline_stage.name}»
        del pipeline «#{@deal.pipeline.name}»#{" por el usuario #{@user.name}" if @user}.

        Instrucción configurada para esta etapa:
        #{@trigger.instructions}
      INPUT
    end

    def tool_definitions
      [
        {type: "function", name: "get_deal_context",
         description: "Devuelve el contexto completo del deal: campos, valor, productos, contactos, tareas, notas y actividad reciente.",
         parameters: {type: "object", properties: {}, additionalProperties: false}},
        {type: "function", name: "get_company_context",
         description: "Devuelve el contexto de la empresa asociada al deal.",
         parameters: {type: "object", properties: {}, additionalProperties: false}},
        {type: "function", name: "get_contact_context",
         description: "Devuelve el contexto de un contacto del deal. Sin person_id usa el primer contacto.",
         parameters: {type: "object", additionalProperties: false, properties: {
           person_id: {type: "integer", description: "Id de un contacto del deal"}
         }}},
        {type: "function", name: "show_toast",
         description: "Muestra una notificación breve y no bloqueante en el navegador del usuario.",
         parameters: {type: "object", additionalProperties: false, required: ["message"], properties: {
           message: {type: "string"},
           kind: {type: "string", enum: %w[info success warning]}
         }}},
        {type: "function", name: "show_alert",
         description: "Muestra un diálogo modal informativo que el usuario debe cerrar.",
         parameters: {type: "object", additionalProperties: false, required: ["message"], properties: {
           message: {type: "string"}, title: {type: "string"}
         }}},
        {type: "function", name: "show_confirm",
         description: "Muestra un diálogo de confirmación. Si el usuario acepta se ejecuta el seguimiento: visit navega a una ruta interna (follow_up_url debe empezar por /), toast muestra follow_up_message.",
         parameters: {type: "object", additionalProperties: false, required: %w[message follow_up_type], properties: {
           message: {type: "string"}, title: {type: "string"},
           follow_up_type: {type: "string", enum: %w[visit toast]},
           follow_up_url: {type: "string", description: "Ruta interna, p.ej. /deals/123"},
           follow_up_message: {type: "string"}
         }}},
        {type: "function", name: "show_deal_panel",
         description: "Muestra un panel persistente dentro de la página del deal. Admite markdown.",
         parameters: {type: "object", additionalProperties: false, required: ["markdown"], properties: {
           markdown: {type: "string"}, title: {type: "string"}
         }}}
      ]
    end

    def execute_tool(name, args)
      result = dispatch_tool(name, args)
      append_transcript("type" => "tool_call", "name" => name, "arguments" => args,
        "result_preview" => result.to_s.truncate(500))
      result
    rescue ArgumentError => e
      append_transcript("type" => "tool_call", "name" => name, "arguments" => args, "error" => e.message)
      "Error: #{e.message}"
    end

    def dispatch_tool(name, args)
      case name
      when "get_deal_context"
        Ai::RecordContextBuilder.new(record: @deal, user: @user).to_prompt
      when "get_company_context"
        return "El deal no tiene empresa asociada." unless @deal.company

        Ai::RecordContextBuilder.new(record: @deal.company, user: @user).to_prompt
      when "get_contact_context"
        contact = find_contact(args["person_id"])
        return "El deal no tiene ese contacto." unless contact

        Ai::RecordContextBuilder.new(record: contact, user: @user).to_prompt
      when *UI_TOOLS
        @ui.public_send(name, **args.symbolize_keys)
        "ok"
      else
        "Herramienta desconocida: #{name}"
      end
    end

    # Contacts are resolved inside the deal's graph only — never a global find.
    def find_contact(person_id)
      return @deal.contacts.first if person_id.blank?

      @deal.contacts.find_by(id: person_id)
    end

    def append_transcript(entry)
      @run.transcript << entry
      @run.save!
    end
  end
end
