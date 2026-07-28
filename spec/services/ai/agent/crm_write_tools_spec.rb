require "rails_helper"

RSpec.describe Ai::Agent::CrmWriteTools do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:ctx) { UserContext.new(user: user, workspace: workspace) }
  let(:company) { companies(:acme) }
  let(:pending_actions) { [] }
  let(:tools) { described_class.new(ctx: ctx, pending_actions: pending_actions) }

  it "proposes a task without creating it" do
    result = tools.try_execute("create_task", { "title" => "Llamar mañana", "record_type" => "company", "record_id" => company.id })

    expect(result).to include("Pendiente de confirmación")
    expect(pending_actions.size).to eq(1)
    expect(pending_actions.first.tool).to eq("create_task")
    expect(workspace.tasks.where(title: "Llamar mañana")).to be_empty
  end

  it "proposes a note without creating it" do
    result = tools.try_execute("add_note", {
      "record_type" => "company",
      "record_id" => company.id,
      "body" => "Nota de prueba"
    })

    expect(result).to include("Pendiente de confirmación")
    expect(pending_actions.first.tool).to eq("add_note")
    expect(company.notes.where(body: "Nota de prueba")).to be_empty
  end

  it "returns forbidden when the user cannot update the record" do
    other_company = companies(:globex)
    result = tools.try_execute("update_record", {
      "record_type" => "company",
      "record_id" => other_company.id,
      "fields" => { "name" => "Hacked" }
    })

    expect(result).to match(/not found|Forbidden/i)
    expect(pending_actions).to be_empty
  end
end
