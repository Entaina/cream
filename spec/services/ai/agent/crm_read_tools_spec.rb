require "rails_helper"

RSpec.describe Ai::Agent::CrmReadTools do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:ctx) { UserContext.new(user: user, workspace: workspace) }
  let(:company) { companies(:acme) }
  let(:tools) { described_class.new(ctx: ctx) }

  it "searches records within the workspace" do
    result = JSON.parse(tools.try_execute("search_records", { "query" => "Acme" }))

    expect(result["companies"].map { |c| c["name"] }).to include("Acme Corp")
  end

  it "returns record context for an authorized record" do
    result = JSON.parse(tools.try_execute("get_record", { "record_type" => "company", "record_id" => company.id }))

    expect(result["name"]).to eq("Acme Corp")
  end

  it "returns forbidden for a record outside the workspace" do
    other_company = companies(:globex)
    result = tools.try_execute("get_record", { "record_type" => "company", "record_id" => other_company.id })

    expect(result).to match(/not found|Forbidden/i)
  end
end
