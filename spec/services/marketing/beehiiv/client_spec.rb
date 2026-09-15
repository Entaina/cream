require "rails_helper"

RSpec.describe Marketing::Beehiiv::Client do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:publication) { create_beehiiv_publication!(workspace) }
  let(:client) { described_class.new(publication) }
  let(:http) { instance_double(Net::HTTP) }

  before do
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
  end

  def success_response(body)
    instance_double(Net::HTTPSuccess, body: body.to_json, code: "200").tap do |response|
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end
  end

  it "lists subscriptions with bearer auth" do
    request = instance_double(Net::HTTP::Get)
    allow(Net::HTTP::Get).to receive(:new).and_return(request)
    allow(request).to receive(:[]=)
    allow(http).to receive(:request).and_return(
      success_response("data" => [], "has_more" => false)
    )

    client.list_subscriptions(limit: 50)

    expect(request).to have_received(:[]=).with("Authorization", "Bearer beehiiv-api-key")
  end

  it "creates subscriptions without welcome email" do
    request = instance_double(Net::HTTP::Post)
    captured_body = nil
    allow(Net::HTTP::Post).to receive(:new).and_return(request)
    allow(request).to receive(:[]=)
    allow(request).to receive(:body=) { |value| captured_body = value }
    allow(http).to receive(:request).and_return(
      success_response("data" => {"id" => "sub_new"})
    )

    response = client.create_subscription(email: "new@example.com", reactivate_existing: true)

    expect(JSON.parse(captured_body)).to include(
      "email" => "new@example.com",
      "send_welcome_email" => false,
      "double_opt_override" => "off"
    )
    expect(response.dig("data", "id")).to eq("sub_new")
  end
end
