require "rails_helper"

RSpec.describe Ai::EmailDrafter do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "alex@acme.test") }
  let(:client) { instance_double(Ai::Client) }

  it "returns subject and body" do
    allow(client).to receive(:chat).and_return({ subject: "Quick follow-up", body: "Hi Alex," }.to_json)

    result = described_class.new(record: person, goal: "Follow up after demo", client: client).call

    expect(result[:subject]).to eq("Quick follow-up")
    expect(result[:body]).to eq("Hi Alex,")
  end
end
