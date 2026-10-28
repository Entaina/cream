require "rails_helper"

RSpec.describe SlackNotifier do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  before do
    SlackIntegration.create!(
      workspace: workspace,
      webhook_url: "https://hooks.slack.com/services/T000/B000/xyz",
      notify_events: ["deal.stage_changed"]
    )
  end

  it "posts the message to the validated address of the Slack webhook" do
    allow(Resolv).to receive(:getaddresses).with("hooks.slack.com").and_return(["34.226.36.79"])
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with("hooks.slack.com", 443).and_return(http)
    allow(http).to receive_messages(:ipaddr= => nil, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil)
    allow(http).to receive(:start).and_yield
    allow(http).to receive(:request)

    described_class.notify(workspace: workspace, event: "deal.stage_changed", message: "Deal moved")

    expect(http).to have_received(:ipaddr=).with("34.226.36.79")
    expect(http).to have_received(:request) { |request| expect(JSON.parse(request.body)).to eq("text" => "Deal moved") }
  end

  it "does not connect when the webhook host resolves to a private address" do
    allow(Resolv).to receive(:getaddresses).with("hooks.slack.com").and_return(["127.0.0.1"])
    allow(Net::HTTP).to receive(:new)

    expect {
      described_class.notify(workspace: workspace, event: "deal.stage_changed", message: "Deal moved")
    }.to raise_error(ArgumentError, /private address/)
    expect(Net::HTTP).not_to have_received(:new)
  end

  it "does nothing when no integration listens to the event" do
    allow(Net::HTTP).to receive(:new)

    described_class.notify(workspace: workspace, event: "mention", message: "Hi")

    expect(Net::HTTP).not_to have_received(:new)
  end
end
