require "rails_helper"

RSpec.describe WebhookDeliveryJob, type: :job do
  fixtures :users, :workspaces, :memberships

  let(:webhook) do
    Webhook.create!(
      workspace: workspaces(:one),
      user: users(:one),
      url: "https://example.com/hook",
      events: ["record.created"]
    )
  end

  it "delivers webhook payload over HTTP to the validated address" do
    allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["93.184.216.34"])
    response = instance_double(Net::HTTPSuccess, code: "200", body: "ok", is_a?: true)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with("example.com", 443).and_return(http)
    allow(http).to receive_messages(:ipaddr= => nil, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
    allow(http).to receive(:start).and_yield
    allow(http).to receive(:request).and_return(response)

    described_class.perform_now(webhook.id, "record.created", {id: 1})

    expect(http).to have_received(:ipaddr=).with("93.184.216.34")
    expect(WebhookDelivery.last.status).to eq("delivered")
  end

  it "marks the delivery failed when the host resolves to a private address" do
    allow(Resolv).to receive(:getaddresses).with("example.com").and_return(["10.0.0.5"])
    allow(Net::HTTP).to receive(:new)

    described_class.perform_now(webhook.id, "record.created", {id: 1})

    expect(Net::HTTP).not_to have_received(:new)
    expect(WebhookDelivery.last).to have_attributes(status: "failed", response_body: /private address/)
  end
end
