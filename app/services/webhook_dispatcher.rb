class WebhookDispatcher
  def self.dispatch(workspace:, event:, payload:)
    workspace.webhooks.active.where("events @> ?", [event].to_json).find_each do |webhook|
      WebhookDeliveryJob.perform_later(webhook.id, event, payload)
    end
  end
end
