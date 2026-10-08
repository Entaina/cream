require "rails_helper"

RSpec.describe Ai::Agent::McpTools do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { companies(:acme) }
  let(:pending_actions) { [] }
  let(:tools) { described_class.new(workspace: workspace, user: user, pending_actions: pending_actions) }

  it "classifies every MCP tool as a read or a confirmed write" do
    expect(CreamMcp.tools.map(&:name_value)).to match_array(described_class::READ_ONLY + described_class::WRITE)
  end

  it "exposes the MCP catalogue, including tools the chat did not have before" do
    names = tools.definitions.map { |tool| tool[:name] }

    expect(names).to include("list_people", "send_campaign", "draft_email", "create_company")
    expect(names).not_to include("search_okm", "remember")
    expect(tools.definitions.find { |tool| tool[:name] == "create_company" }[:description]).to include("confirmation")
  end

  it "runs a read tool immediately" do
    result = tools.try_execute("search_records", { "query" => company.name })

    expect(result).to include(company.name)
    expect(pending_actions).to be_empty
  end

  it "proposes a write tool without applying it" do
    result = tools.try_execute("create_company", { "name" => "No creada todavía" })

    expect(result).to include("Pendiente de confirmación")
    expect(workspace.companies.find_by(name: "No creada todavía")).to be_nil
    expect(pending_actions.map(&:tool)).to eq([ "create_company" ])
  end

  it "hides write tools when writes are disabled" do
    readonly = described_class.new(workspace: workspace, user: user, pending_actions: pending_actions, write: false)

    expect(readonly.definitions.map { |tool| tool[:name] }).not_to include("create_company")
    expect(readonly.try_execute("delete_record", { "record_type" => "company", "record_id" => company.id })).to include("Forbidden")
    expect(company.reload).to be_present
  end
end
