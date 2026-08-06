require "rails_helper"

RSpec.describe "Lead form templates", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:admin) { users(:one) }
  let(:salesperson) { users(:two) }
  let(:workspace) { workspaces(:one) }

  describe "admin CRUD" do
    before { sign_in_as(admin) }

    it "lists templates" do
      workspace.lead_form_templates.create!(
        path: "public/lead_forms/demo",
        partial: false,
        body: "<p>demo</p>"
      )

      get lead_form_templates_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("demo")
      expect(response.body).not_to include("public/lead_forms/demo")
      expect(response.body).to include('data-controller="liquid-preview"')
    end

    it "filters templates by kind" do
      workspace.lead_form_templates.create!(
        path: "public/lead_forms/demo",
        partial: false,
        body: "<p>demo</p>"
      )
      workspace.lead_form_templates.create!(
        path: "public/lead_forms/partials/how_heard_field",
        partial: true,
        body: "<p>how heard</p>"
      )

      get lead_form_templates_path(kind: "partial")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("how_heard_field")
      expect(response.body).not_to include("demo")
    end

    it "creates a template" do
      expect {
        post lead_form_templates_path, params: {
          lead_form_template: {
            slug: "custom",
            partial: "1",
            body: "<p>Custom template</p>"
          }
        }
      }.to change(LeadFormTemplate, :count).by(1)

      expect(response).to redirect_to(lead_form_templates_path)
      expect(LeadFormTemplate.last.path).to eq("public/lead_forms/partials/custom")
    end

    it "updates a template" do
      template = workspace.lead_form_templates.create!(
        path: "public/lead_forms/demo",
        partial: false,
        body: "<p>old</p>"
      )

      patch lead_form_template_path(template), params: {
        lead_form_template: { body: "<p>new</p>" }
      }

      expect(response).to redirect_to(lead_form_templates_path)
      expect(template.reload.body).to include("new")
    end

    it "destroys a template" do
      template = workspace.lead_form_templates.create!(
        path: "public/lead_forms/demo",
        partial: false,
        body: "<p>demo</p>"
      )

      expect {
        delete lead_form_template_path(template)
      }.to change(LeadFormTemplate, :count).by(-1)

      expect(response).to redirect_to(lead_form_templates_path)
    end

    it "shows Plantillas de formulario link on lead forms index" do
      get lead_forms_path

      expect(response.body).to include("Plantillas de formulario")
      expect(response.body).to include(lead_form_templates_path)
    end
  end

  describe "non-admin access" do
    before do
      sign_in_as(salesperson)
      patch switch_workspace_path, params: { workspace_id: workspace.id }
    end

    it "forbids listing templates" do
      get lead_form_templates_path

      expect(response).to redirect_to(root_path)
    end

    it "forbids creating templates" do
      post lead_form_templates_path, params: {
        lead_form_template: {
          slug: "demo",
          partial: "0",
          body: "<p>demo</p>"
        }
      }

      expect(response).to redirect_to(root_path)
      expect(LeadFormTemplate.count).to eq(0)
    end

    it "does not show Plantillas de formulario link on lead forms index" do
      get lead_forms_path

      expect(response.body).not_to include("Plantillas de formulario")
    end
  end
end
