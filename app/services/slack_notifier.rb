require "net/http"

class SlackNotifier
  def self.notify(workspace:, event:, message:)
    integration = workspace.slack_integrations.active.find { |i| Array(i.notify_events).include?(event) }
    return unless integration

    uri = URI.parse(integration.webhook_url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {text: message}.to_json

    SafeOutboundHttp.start(uri) { |http| http.request(request) }
  end
end
