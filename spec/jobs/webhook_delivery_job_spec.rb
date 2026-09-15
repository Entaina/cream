require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  fixtures :users, :workspaces, :memberships

  it "delivers webhook payload over HTTP" do
    webhook = Webhook.create!(
      workspace: workspaces(:one),
      user: users(:one),
      url: "https://example.com/hook",
      events: ["record.created"]
    )

    response = instance_double(Net::HTTPSuccess, code: "200", body: "ok", is_a?: true)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)

    described_class.perform_now(webhook.id, "record.created", {id: 1})

    expect(WebhookDelivery.last.status).to eq("delivered")
  end
end
