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
        @message = I18n.t("booking.errors.api_disabled")
        return
      end

      if @http_code == 403
        @code = :insufficient_scopes
        @message = I18n.t("booking.errors.insufficient_scopes", operation: operation_label)
        return
      end

      @code = :api_error
      @message = api_failed_message(error["message"].presence || @body.truncate(200))
    rescue JSON::ParserError
      @code = :api_error
      @message = api_failed_message(@body.truncate(200))
    end

    def operation_label
      I18n.t("booking.errors.operations.#{@operation}", default: @operation.to_s)
    end

    def api_failed_message(detail)
      I18n.t("booking.errors.api_failed", operation: operation_label, code: @http_code, detail: detail)
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
