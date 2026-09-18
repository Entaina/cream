require "rails_helper"

RSpec.describe Marketing::Esp::MailjetWebhookRegistrar do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let!(:connection) do
    workspace.create_mailjet_connection!(
      user: user,
      api_key: "api-key-xxxx",
      secret_key: "secret-yyyy",
      from_email: "noreply@example.com",
      webhook_token: "test-webhook-token"
    )
  end
  let(:http) { instance_double(Net::HTTP) }
  let(:webhook_url) { connection.webhook_url }
  let(:requests) { [] }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(Net::HTTP::Get).to receive(:new) { |uri| build_request(:get, uri) }
    allow(Net::HTTP::Post).to receive(:new) { |uri| build_request(:post, uri) }
    allow(Net::HTTP::Delete).to receive(:new) { |uri| build_request(:delete, uri) }
  end

  def build_request(method, uri)
    body = nil
    instance_double("Request#{method}", uri: uri, method: method, body: body).tap do |request|
      allow(request).to receive(:basic_auth)
      allow(request).to receive(:[]=)
      allow(request).to receive(:body=) { |value| body = value }
      allow(request).to receive(:body) { body }
      requests << request
    end
  end

  def success_response(body)
    instance_double(Net::HTTPSuccess, body: body.to_json, code: "200").tap do |response|
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }
    end
  end

  it "creates missing event callbacks with Version 2" do
    allow(http).to receive(:request).and_return(
      success_response("Data" => []),
      *Array.new(described_class::EVENT_TYPES.size, success_response("Count" => 1))
    )

    described_class.sync!(connection)

    post_bodies = requests.select { |request| request.method == :post }.map do |request|
      JSON.parse(request.body)
    end

    expect(post_bodies.size).to eq(described_class::EVENT_TYPES.size)
    expect(post_bodies).to all(include("Version" => 2, "Url" => webhook_url))
    expect(post_bodies.map { |body| body["EventType"] }).to match_array(described_class::EVENT_TYPES)
  end

  it "recreates dead callbacks" do
    allow(http).to receive(:request).and_return(
      success_response("Data" => [{
        "ID" => 2_173_940,
        "EventType" => "open",
        "Status" => "dead",
        "Version" => 1,
        "Url" => webhook_url
      }]),
      success_response("Count" => 1),
      success_response("Count" => 1),
      *Array.new(described_class::EVENT_TYPES.size - 1, success_response("Count" => 1))
    )

    expect {
      described_class.sync!(connection)
    }.not_to raise_error

    expect(requests.count { |request| request.method == :delete }).to eq(1)
    expect(requests.count { |request| request.method == :post }).to eq(described_class::EVENT_TYPES.size)
  end

  it "removes callbacks for the workspace webhook URL" do
    allow(http).to receive(:request).and_return(
      success_response("Data" => [{
        "ID" => 2_173_940,
        "EventType" => "open",
        "Status" => "alive",
        "Version" => 2,
        "Url" => webhook_url
      }]),
      success_response("Count" => 1)
    )

    described_class.remove!(connection)

    expect(requests.count { |request| request.method == :delete }).to eq(1)
  end
end
