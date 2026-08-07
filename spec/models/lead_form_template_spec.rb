require "rails_helper"

RSpec.describe LeadFormTemplate, type: :model do
  fixtures :workspaces

  let(:workspace) { workspaces(:one) }

  describe "submission schema" do
    it "compiles and stores the schema when saving a form page" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

      expect(template.submission_schema).to include("fields")
      expect(template.submission_schema["fields"].map { |field| field["name"] }).to include("email", "help_type", "gdpr_consent")
    end

    it "does not compile submission schema for partials" do
      template = workspace.lead_form_templates.create!(
        path: "public/lead_forms/partials/custom_fields",
        partial: true,
        body: "{% field type: \"text\", name: \"custom\", label: \"Custom\" %}"
      )

      expect(template.submission_schema).to eq({})
    end
  end

  describe "validations" do
    it "is valid with allowed path and Liquid body" do
      template = workspace.lead_form_templates.build(
        path: "public/lead_forms/contacto",
        partial: false,
        body: "<div>{% partial 'contact_fields' %}</div>"
      )

      expect(template).to be_valid
    end

    it "rejects paths outside public/lead_forms" do
      template = workspace.lead_form_templates.build(
        path: "layouts/application",
        partial: false,
        body: "<p>bad</p>"
      )

      expect(template).not_to be_valid
      expect(template.errors[:path]).to be_present
    end

    it "enforces unique path per workspace" do
      workspace.lead_form_templates.create!(
        path: "public/lead_forms/contacto",
        partial: false,
        body: "<p>contacto</p>"
      )

      duplicate = workspace.lead_form_templates.build(
        path: "public/lead_forms/contacto",
        partial: true,
        body: "<p>other</p>"
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:path]).to be_present
    end

    it "rejects invalid Liquid syntax" do
      template = workspace.lead_form_templates.build(
        path: "public/lead_forms/contacto",
        partial: true,
        body: "{% if %}"
      )

      expect(template).not_to be_valid
      expect(template.errors[:body]).to be_present
    end
  end

  describe "#display_name and slug" do
    it "shows the short name without the public/lead_forms prefix" do
      template = workspace.lead_form_templates.build(
        path: "public/lead_forms/contacto",
        partial: false,
        body: "<p>ok</p>"
      )

      expect(template.display_name).to eq("contacto")
    end

    it "builds the stored path from slug and partial flag" do
      template = workspace.lead_form_templates.build(
        slug: "contact_fields",
        partial: true,
        body: "<p>ok</p>"
      )

      expect(template).to be_valid
      expect(template.path).to eq("public/lead_forms/partials/contact_fields")
    end
  end

  describe ".template_key_for" do
    it "returns the template key for template paths" do
      expect(described_class.template_key_for("public/lead_forms/demo")).to eq("demo")
    end

    it "returns nil for non-template paths" do
      expect(described_class.template_key_for("public/lead_forms/success")).to be_nil
      expect(described_class.template_key_for("public/lead_forms/partials/contact_fields")).to be_nil
    end
  end
end
