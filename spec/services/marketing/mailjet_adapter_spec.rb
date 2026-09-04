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

  before do
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  def success_response(body)
    instance_double(Net::HTTPSuccess, body: body.to_json, code: "200").tap do |response|
      allow(response).to receive(:is_a?) { |klass| klass == Net::HTTPSuccess }
    end
  end

  it "sends via the workspace Mailjet credentials and stores the ESP id" do
    request = instance_double(Net::HTTP::Post)
    allow(Net::HTTP::Post).to receive(:new).and_return(request)
    allow(request).to receive(:basic_auth)
    allow(request).to receive(:[]=)
    allow(request).to receive(:body=)
    allow(http).to receive(:request).and_return(
      success_response("Messages" => [ { "To" => [ { "MessageID" => 99 } ] } ])
    )

    expect(described_class.new(message).deliver!).to be(true)
    expect(request).to have_received(:basic_auth).with("api-key-xxxx", "secret-yyyy")
    expect(message.reload.esp_message_id).to eq("99")
  end

  it "does not call Mailjet when the workspace is not connected" do
    connection.destroy!
    workspace.reload

    expect(Net::HTTP).not_to receive(:start)
    expect(described_class.new(message.reload).deliver!).to be(false)
    expect(EmailEvent.last.event_type).to eq("blocked")
  end
end
