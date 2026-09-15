require "rails_helper"

RSpec.describe Ai::RecordSummarizer do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:person) { create_person!(workspace, company: companies(:acme), email: "alex@acme.test") }
  let(:client) { instance_double(Ai::Client) }

  it "normalizes structured summary output" do
    allow(client).to receive(:chat).and_return({
      summary: "Active contact",
      risks: ["No recent email"],
      next_steps: ["Schedule follow-up"],
      missing_data: ["Phone number"]
    }.to_json)

    result = described_class.new(record: person, client: client).call

    expect(result[:summary]).to eq("Active contact")
    expect(result[:risks]).to eq(["No recent email"])
    expect(result[:next_steps]).to eq(["Schedule follow-up"])
    expect(result[:missing_data]).to eq(["Phone number"])
  end
end
