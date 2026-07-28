require "net/http"
require "json"

module GoogleCalendar
  class Error < StandardError
    attr_reader :code, :help_url

    def initialize(message, code: :api_error, help_url: nil)
      super(message)
      @code = code
      @help_url = help_url
    end

    def self.from_response(operation, response)
      api_error = ApiError.from_http_response(operation, response)
      new(api_error.message, code: api_error.code, help_url: api_error.help_url)
    end
  end

  class Client
    include GoogleOauthTokenRefresh

    BASE_URI = "https://www.googleapis.com/calendar/v3".freeze

    def initialize(connection)
      @connection = connection
    end

    def free_busy(time_min:, time_max:, calendar_ids:, timezone:)
      bearer = ensure_access_token!(@connection)
      payload = {
        timeMin: time_min.iso8601,
        timeMax: time_max.iso8601,
        timeZone: timezone,
        items: calendar_ids.map { |calendar_id| { id: calendar_id } }
      }
      response = post_json(URI("#{BASE_URI}/freeBusy"), payload, bearer: bearer)
      raise Error.from_response("consultar disponibilidad", response) unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      busy = []
      data.fetch("calendars", {}).each_value do |calendar|
        Array(calendar["busy"]).each do |period|
          busy << {
            start: Time.zone.parse(period["start"]),
            end: Time.zone.parse(period["end"])
          }
        end
      end
      busy.sort_by { |period| period[:start] }
    end

    def create_event(calendar_id:, event:)
      bearer = ensure_access_token!(@connection)
      uri = URI("#{BASE_URI}/calendars/#{CGI.escape(calendar_id)}/events")
      uri.query = URI.encode_www_form(conferenceDataVersion: 1, sendUpdates: "all")
      response = post_json(uri, event, bearer: bearer)
      raise Error.from_response("crear eventos", response) unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def list_calendars
      bearer = ensure_access_token!(@connection)
      uri = URI("#{BASE_URI}/users/me/calendarList")
      response = get_json(uri, bearer: bearer)
      raise Error.from_response("listar calendarios", response) unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      Array(data["items"]).filter_map do |item|
        next if item["id"].blank?

        access_role = item["accessRole"].to_s
        next unless access_role.in?(%w[owner writer reader freeBusyReader])

        {
          id: item["id"],
          summary: item["summary"].presence || item["id"],
          primary: item["primary"] == true,
          writable: access_role.in?(%w[owner writer])
        }
      end.sort_by { |item| [ item[:primary] ? 0 : 1, item[:summary].downcase ] }
    end
  end
end
