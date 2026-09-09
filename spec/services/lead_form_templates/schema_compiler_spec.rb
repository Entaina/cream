require "rails_helper"

RSpec.describe LeadFormTemplates::SchemaCompiler do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  before { import_lead_form_templates!(workspace) }

  it "marks company fields as requiring collects_company" do
    template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/demo")
    schema = described_class.compile(template: template)
    company = schema["fields"].find { |field| field["name"] == "company_name" }

    expect(company).to include("requires_collects_company" => true)
  end

  it "marks edition_id as requiring open editions with dynamic allowed values" do
    template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/reserva")
    schema = described_class.compile(template: template)
    edition = schema["fields"].find { |field| field["name"] == "edition_id" }

    expect(edition).to include(
      "requires_open_editions" => true,
      "dynamic_allowed_values" => "open_editions"
    )
  end
end
