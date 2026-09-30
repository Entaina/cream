require "rails_helper"

RSpec.describe LeadFormTemplates::Importer do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  it "imports all repository templates into the workspace" do
    result = described_class.import!(workspace)

    expect(result[:total]).to eq(15)
    expect(result[:created]).to eq(15)
    expect(result[:updated]).to eq(0)
    expect(workspace.lead_form_templates.find_by!(path: "public/lead_forms/success").body).to include("Gracias")
    expect(workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto").partial).to be(false)
    expect(workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto").submission_schema["fields"]).to be_present
    expect(workspace.lead_form_templates.find_by!(path: "public/lead_forms/partials/contact_fields").partial).to be(true)
    expect(workspace.lead_form_templates.find_by!(path: "public/lead_forms/partials/contact_fields").submission_schema).to eq({})
    expect(workspace.lead_form_templates.find_by!(path: "public/layouts/booking_default").kind).to eq("layout")
  end

  it "is idempotent on a second run" do
    described_class.import!(workspace)

    expect {
      result = described_class.import!(workspace)
      expect(result[:created]).to eq(0)
      expect(result[:updated]).to eq(0)
    }.not_to change(LeadFormTemplate, :count)
  end
end
