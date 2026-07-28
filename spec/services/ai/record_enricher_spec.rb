require "rails_helper"

RSpec.describe Ai::RecordEnricher do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:company) { companies(:acme) }
  let(:client) { instance_double(Ai::Client) }

  it "returns only allowed field suggestions" do
    allow(client).to receive(:chat).and_return({
      summary: "Company profile can be improved",
      suggestions: [
        { field: "industry", current: nil, suggested: "Software", reason: "Mentioned in notes" },
        { field: "invalid_field", current: nil, suggested: "X", reason: "ignored" }
      ]
    }.to_json)

    result = described_class.new(record: company, client: client).call

    expect(result[:suggestions].size).to eq(1)
    expect(result[:suggestions].first[:field]).to eq("industry")
  end
end
