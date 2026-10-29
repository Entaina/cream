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
    result = tools.try_execute("search_records", {"query" => company.name})

    expect(result).to include(company.name)
    expect(pending_actions).to be_empty
  end

  it "proposes a write tool without applying it" do
    result = tools.try_execute("create_company", {"name" => "No creada todavía"})

    expect(result).to include("Pendiente de confirmación")
    expect(workspace.companies.find_by(name: "No creada todavía")).to be_nil
    expect(pending_actions.map(&:tool)).to eq(["create_company"])
  end

  it "shows the recipient, subject and full body of a proposed email" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:record_email).and_return(true)
    contact = create_person!(workspace, company: company, email: "cliente@example.com")
    deal = create_deal!(workspace, company: company, contacts: [contact])
    body = "Hola,\n\n#{"Texto largo. " * 20}\nTransfiere el pago a ES00 0000"

    tools.try_execute("send_deal_email", {"deal_id" => deal.id, "subject" => "Factura", "body" => body})

    action = pending_actions.sole
    expect(action.preview).to eq("to" => "cliente@example.com", "subject" => "Factura", "body" => body)
    expect(EmailMessage.where(record: deal)).to be_empty
  end

  it "shows the explicit recipient of a proposed person email" do
    person = create_person!(workspace, company: company, email: "persona@example.com")

    tools.try_execute("send_person_email", {"person_id" => person.id, "to_address" => "otra@example.com", "subject" => "Hola", "body" => "Cuerpo"})

    expect(pending_actions.sole.preview).to eq("to" => "otra@example.com", "subject" => "Hola", "body" => "Cuerpo")
  end

  it "has no preview for writes that send nothing" do
    tools.try_execute("create_company", {"name" => "Sin vista previa"})

    expect(pending_actions.sole.preview).to be_nil
  end

  it "hides write tools when writes are disabled" do
    readonly = described_class.new(workspace: workspace, user: user, pending_actions: pending_actions, write: false)

    expect(readonly.definitions.map { |tool| tool[:name] }).not_to include("create_company")
    expect(readonly.try_execute("delete_record", {"record_type" => "company", "record_id" => company.id})).to include("Forbidden")
    expect(company.reload).to be_present
  end
end
