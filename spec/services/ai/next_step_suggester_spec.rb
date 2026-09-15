require "rails_helper"

RSpec.describe Ai::NextStepSuggester do
  fixtures :users, :workspaces, :companies, :memberships

  let(:workspace) { workspaces(:one) }
  let(:deal) { create_deal!(workspace, company: companies(:acme)) }
  let(:client) { instance_double(Ai::Client) }

  it "normalizes actionable suggestions" do
    allow(client).to receive(:chat).and_return({
      deal_risk: "high",
      summary: "Deal needs attention",
      suggestions: [
        {kind: "task", title: "Confirm budget", due_on: "2026-07-05", reason: "Close date is near"}
      ]
    }.to_json)

    result = described_class.new(record: deal, client: client).call

    expect(result[:deal_risk]).to eq("high")
    expect(result[:suggestions].first[:title]).to eq("Confirm budget")
    expect(result[:suggestions].first[:due_on]).to eq(Date.new(2026, 7, 5))
  end
end
