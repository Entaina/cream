require "rails_helper"

RSpec.describe GmailReader do
  fixtures :users, :workspaces, :memberships

  let(:connection) do
    workspaces(:one).gmail_connections.create!(
      user: users(:one), email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now,
      granted_scopes: GmailConnection::METADATA_SCOPE
    )
  end

  def http_double
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    tokeninfo = instance_double(Net::HTTPResponse, body: {scope: GmailConnection::METADATA_SCOPE}.to_json)
    allow(http).to receive(:get).and_return(tokeninfo)
    http
  end

  def success(body)
    response = instance_double(Net::HTTPSuccess, body: body.to_json)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    response
  end

  it "lists recent message ids without search query when metadata scope is granted" do
    http = http_double
    list_response = success({messages: [{id: "m1"}, {id: "m2"}]})
    allow(http).to receive(:request).and_return(list_response)

    ids = described_class.new(connection).list_recent_message_ids(after: 1.hour.ago)

    expect(ids).to eq(%w[m1 m2])
  end

  it "lists recent message ids with search query when only readonly scope is granted" do
    readonly_connection = workspaces(:one).gmail_connections.create!(
      user: users(:one), email: "me@gmail.com",
      access_token: "at", refresh_token: "rt", expires_at: 1.hour.from_now,
      granted_scopes: GmailConnection::READONLY_SCOPE
    )
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    tokeninfo = instance_double(Net::HTTPResponse, body: {scope: GmailConnection::READONLY_SCOPE}.to_json)
    allow(http).to receive(:get).and_return(tokeninfo)
    list_response = success({messages: [{id: "m1"}]})
    allow(http).to receive(:request).and_return(list_response)

    ids = described_class.new(readonly_connection).list_recent_message_ids(after: 1.hour.ago)

    expect(ids).to eq(%w[m1])
  end

  it "returns metadata for messages in a thread" do
    payload = {
      messages: [
        {
          id: "m1",
          threadId: "t1",
          internalDate: 1.hour.ago.to_i * 1000,
          labelIds: ["INBOX"],
          payload: {
            headers: [
              {name: "From", value: "Alex <alex@example.com>"},
              {name: "Subject", value: "Re: Hi"}
            ]
          }
        }
      ]
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    metadata = described_class.new(connection).get_thread_metadata("t1")

    expect(metadata.size).to eq(1)
    expect(metadata.first.thread_id).to eq("t1")
    expect(metadata.first.from).to include("alex@example.com")
  end

  it "returns metadata for a message" do
    payload = {
      id: "m1",
      threadId: "t1",
      internalDate: 1.hour.ago.to_i * 1000,
      labelIds: ["INBOX"],
      payload: {
        headers: [
          {name: "From", value: "Alex <alex@example.com>"},
          {name: "Subject", value: "Re: Hi"},
          {name: "In-Reply-To", value: "<orig@cream.test>"},
          {name: "References", value: "<orig@cream.test>"}
        ]
      }
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    metadata = described_class.new(connection).get_metadata("m1")

    expect(metadata.thread_id).to eq("t1")
    expect(metadata.from).to include("alex@example.com")
    expect(metadata.in_reply_to).to eq("<orig@cream.test>")
  end

  it "returns full message body from text/plain" do
    plain = Base64.urlsafe_encode64("Thanks for the proposal")
    payload = {
      id: "m2",
      threadId: "t2",
      labelIds: ["INBOX"],
      snippet: "Thanks for",
      payload: {
        mimeType: "text/plain",
        body: {data: plain},
        headers: [
          {name: "From", value: "Alex <alex@example.com>"},
          {name: "Subject", value: "Re: Hi"}
        ]
      }
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    full = described_class.new(connection).get_full("m2")

    expect(full.body_text).to eq("Thanks for the proposal")
    expect(full.from).to include("alex@example.com")
  end

  it "falls back to snippet when body is missing" do
    payload = {
      id: "m3",
      threadId: "t3",
      labelIds: ["INBOX"],
      snippet: "Short preview",
      payload: {
        mimeType: "text/plain",
        body: {},
        headers: [{name: "Subject", value: "Re: Hi"}]
      }
    }
    allow(http_double).to receive(:request).and_return(success(payload))

    full = described_class.new(connection).get_full("m3")

    expect(full.body_text).to eq("Short preview")
  end
end
