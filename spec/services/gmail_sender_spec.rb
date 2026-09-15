require "rails_helper"

RSpec.describe GmailSender do
  fixtures :users, :workspaces, :memberships

  let(:connection) do
    workspaces(:one).gmail_connections.create!(
      user: users(:one), email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now
    )
  end

  def http_double
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    http
  end

  def success(body = "{}")
    response = instance_double(Net::HTTPSuccess, body: body.is_a?(String) ? body : body.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    response
  end

  it "sends a message through the Gmail API and returns ids" do
    allow(http_double).to receive(:request).and_return(success({id: "gm1", threadId: "gt1"}))

    result = described_class.new(connection).send_email(to: "x@y.com", subject: "Hi", html: "<p>hi</p>")

    expect(result.gmail_message_id).to eq("gm1")
    expect(result.gmail_thread_id).to eq("gt1")
    expect(result.rfc822_message_id).to start_with("<")
  end

  it "uses a provided RFC822 Message-ID" do
    allow(http_double).to receive(:request).and_return(success({id: "gm1", threadId: "gt1"}))

    result = described_class.new(connection).send_email(
      to: "x@y.com", subject: "Hi", html: "<p>hi</p>", rfc822_message_id: "<fixed@cream.test>"
    )

    expect(result.rfc822_message_id).to eq("<fixed@cream.test>")
  end

  it "refreshes an expired access token before sending" do
    connection.update!(expires_at: 1.hour.ago)
    refresh = success({access_token: "new-token", expires_in: 3600}.to_json)

    allow(http_double).to receive(:request).and_return(refresh, success({id: "gm1", threadId: "gt1"}))

    described_class.new(connection).send_email(to: "x@y.com", subject: "Hi", html: "<p>hi</p>")

    expect(connection.reload.access_token).to eq("new-token")
  end

  it "raises when there is no refresh token" do
    connection.update!(refresh_token: nil)

    expect { described_class.new(connection).send_email(to: "x@y.com", subject: "Hi", html: "<p>hi</p>") }
      .to raise_error(GmailSender::Error)
  end

  it "raises when the API responds with an error" do
    failure = instance_double(Net::HTTPBadRequest, code: "400", body: "nope")
    allow(failure).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    allow(http_double).to receive(:request).and_return(failure)

    expect { described_class.new(connection).send_email(to: "x@y.com", subject: "Hi", html: "<p>hi</p>") }
      .to raise_error(GmailSender::Error)
  end

  it "sends attachments as multipart MIME" do
    captured_body = nil
    allow(http_double).to receive(:request) do |request|
      captured_body = JSON.parse(request.body)
      success({id: "gm1", threadId: "gt1"})
    end

    attachments = [{filename: "doc.pdf", content_type: "application/pdf", content: "%PDF-1.4"}]
    described_class.new(connection).send_email(
      to: "x@y.com", subject: "Hi", html: "<p>hi</p>", attachments: attachments
    )

    raw_mime = Base64.urlsafe_decode64(captured_body["raw"])
    expect(raw_mime).to include("Content-Disposition: attachment")
    expect(raw_mime).to include("doc.pdf")
  end
end
