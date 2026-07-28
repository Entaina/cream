require "rails_helper"

RSpec.describe Ai::Agent::ActionExecutor do
  fixtures :users, :workspaces, :memberships, :companies

  let(:workspace) { workspaces(:one) }
  let(:user) { users(:one) }
  let(:company) { companies(:acme) }
  let(:executor) { described_class.new(workspace: workspace, user: user) }

  it "creates a task when authorized" do
    action = Ai::Agent::PendingAction.new(
      tool: "create_task",
      args: { "title" => "Seguimiento agente", "record_type" => "company", "record_id" => company.id },
      description: "Crear tarea",
      workspace_id: workspace.id,
      user_id: user.id
    )

    result = executor.execute(action)

    expect(result.success).to be(true)
    expect(workspace.tasks.find_by(title: "Seguimiento agente")).to be_present
  end

  it "adds a note when authorized" do
    action = Ai::Agent::PendingAction.new(
      tool: "add_note",
      args: { "record_type" => "company", "record_id" => company.id, "body" => "Nota del agente" },
      description: "Añadir nota",
      workspace_id: workspace.id,
      user_id: user.id
    )

    result = executor.execute(action)

    expect(result.success).to be(true)
    expect(company.notes.find_by(body: "Nota del agente")).to be_present
  end
end
