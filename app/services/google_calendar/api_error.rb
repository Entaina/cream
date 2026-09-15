module GoogleCalendar
  class ApiError
    attr_reader :code, :message, :help_url

    def self.from_http_response(operation, response)
      new(operation: operation, http_code: response.code.to_i, body: response.body.to_s)
    end

    def initialize(operation:, http_code:, body:)
      @operation = operation
      @http_code = http_code
      @body = body
      parse!
    end

    private

    def parse!
      data = JSON.parse(@body)
      error = data.fetch("error", {})
      details = Array(error["details"])
      error_info = details.find { |detail| detail["@type"].to_s.include?("ErrorInfo") }
      reason = error_info&.dig("reason") || error.dig("errors", 0, "reason")

      if service_disabled?(reason, error)
        @code = :api_disabled
        @help_url = error_info&.dig("metadata", "activationUrl") || help_link(details)
        @message = "La API de Google Calendar no está activada en el proyecto OAuth de Google Cloud. " \
                   "Un administrador debe activarla en Google Cloud Console; puede tardar unos minutos en propagarse."
        return
      end

      if @http_code == 403
        @code = :insufficient_scopes
        @message = "Permisos insuficientes para #{@operation}. Reconecta Google Calendar."
        return
      end

      @code = :api_error
      @message = "#{@operation} falló (#{@http_code}): #{error["message"].presence || @body.truncate(200)}"
    rescue JSON::ParserError
      @code = :api_error
      @message = "#{@operation} falló (#{@http_code}): #{@body.truncate(200)}"
    end

    def service_disabled?(reason, error)
      reason.in?(%w[SERVICE_DISABLED accessNotConfigured]) ||
        error.dig("errors", 0, "reason") == "accessNotConfigured" ||
        error["message"].to_s.include?("Google Calendar API has not been used")
    end

    def help_link(details)
      details.find { |detail| detail["@type"].to_s.include?("Help") }&.dig("links", 0, "url")
    end
  end
end
