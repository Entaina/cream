require "rails_helper"

RSpec.describe Marketing::Esp::MailjetAdapter do
  fixtures :users, :workspaces, :memberships

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:person) { create_person!(workspace, email: "esp@example.com") }
  let(:message) do
    workspace.email_messages.create!(
      user: user,
      record: person,
      to_address: person.email,
      subject: "Hi",
      body: "<p>Hi</p>",
      marketing_send: true
    )
  end
  let!(:connection) do
    workspace.create_mailjet_connection!(
      user: user,
      api_key: "api-key-xxxx",
      secret_key: "secret-yyyy",
      from_email: "noreply@example.com",
      from_name: "Cream"
    )
  end
  let(:http) { instance_double(Net::HTTP) }
  let(:request) { instance_double(Net::HTTP::Post) }

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(Net::HTTP::Post).to receive(:new).and_return(request)
    allow(request).to receive(:basic_auth)
    allow(request).to receive(:[]=)
    allow(request).to receive(:body=)
  end

  def success_response(body)
    instance_double(Net::HTTPSuccess, body: body.to_json, code: "200").tap do |response|
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }
    end
  end

  def error_response(code:, body:)
    instance_double(Net::HTTPResponse, body: body, code: code.to_s).tap do |response|
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }
    end
  end

  it "sends via the workspace Mailjet credentials and stores the ESP id" do
    allow(http).to receive(:request).and_return(
      success_response("Messages" => [{"Status" => "success", "To" => [{"MessageID" => 99}]}])
    )

    expect(described_class.new(message).deliver!).to be(true)
    expect(request).to have_received(:basic_auth).with("api-key-xxxx", "secret-yyyy")
    expect(Net::HTTP).to have_received(:start).with(
      "api.mailjet.com",
      443,
      hash_including(use_ssl: true, open_timeout: 10, read_timeout: 10)
    )
    expect(message.reload.esp_message_id).to eq("99")
    expect(EmailEvent.last.event_type).to eq("sent")
    expect(message.email_events.where(event_type: "delivered")).to be_empty
  end

  it "treats Mailjet Status error as failure even with HTTP 200" do
    allow(http).to receive(:request).and_return(
      success_response(
        "Messages" => [{
          "Status" => "error",
          "Errors" => [{"ErrorCode" => "mj-0001", "ErrorMessage" => "Invalid sender"}]
        }]
      )
    )

    expect(described_class.new(message).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
    expect(message.reload.esp_message_id).to be_blank
  end

  it "records blocked on HTTP error responses" do
    allow(http).to receive(:request).and_return(error_response(code: 401, body: "Unauthorized"))

    expect(described_class.new(message).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
  end

  it "records blocked on network errors" do
    allow(http).to receive(:request).and_raise(Timeout::Error, "timeout")

    expect(described_class.new(message).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
    expect(EmailEvent.last.payload["error"]).to eq("timeout")
  end

  it "does not call Mailjet when the workspace is not connected" do
    connection.destroy!
    workspace.reload

    expect(Net::HTTP).not_to receive(:start)
    expect(described_class.new(message.reload).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
  end
end
