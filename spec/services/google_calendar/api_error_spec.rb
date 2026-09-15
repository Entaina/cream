require "rails_helper"

RSpec.describe GoogleCalendar::ApiError do
  describe ".from_http_response" do
    it "detects disabled Google Calendar API" do
      body = {
        error: {
          code: 403,
          message: "Google Calendar API has not been used in project 1053838014961 before or it is disabled.",
          errors: [{reason: "accessNotConfigured", domain: "usageLimits"}],
          details: [
            {
              "@type" => "type.googleapis.com/google.rpc.ErrorInfo",
              :reason => "SERVICE_DISABLED",
              :metadata => {
                activationUrl: "https://console.developers.google.com/apis/api/calendar-json.googleapis.com/overview?project=1053838014961"
              }
            }
          ]
        }
      }.to_json
      response = instance_double(Net::HTTPResponse, code: "403", body: body)

      error = described_class.from_http_response("listar calendarios", response)

      expect(error.code).to eq(:api_disabled)
      expect(error.message).to include("no está activada")
      expect(error.help_url).to include("calendar-json.googleapis.com")
    end
  end
end
