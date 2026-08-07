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

    it "shows the submission schema on the edit page" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

      get edit_lead_form_template_path(template)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Esquema de validación")
      expect(response.body).to include("lead[email]")
      expect(response.body).to include("lead[help_type]")
      expect(response.body).to include("Vista previa")
      expect(response.body).to include('id="lead-form-template-preview-form"')
      expect(response.body).to include(preview_lead_form_template_path(template))
      expect(response.body).not_to include('formmethod="post"')
    end

    it "does not route preview through PATCH (edit form _method)" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

      post preview_lead_form_template_path(template), params: {
        _method: "patch",
        lead_form_template: { body: template.body }
      }

      expect(response).to have_http_status(:not_found)
    end

    it "previews a saved page template" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

      get preview_lead_form_template_path(template)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Vista previa de plantilla")
      expect(response.body).to include("lead[email]")
      expect(response.body).to include('action="#"')
    end

    it "previews a page template with a selected product" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/liderando_ia_reserva")
      product = workspace.products.create!(name: "Liderando con IA", price: 990)
      product.editions.create!(name: "Marzo 2026", starts_on: Date.current + 30.days, ends_on: Date.current + 60.days)

      get preview_lead_form_template_path(template, preview_product_id: product.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="' + product.id.to_s + '"')
      expect(response.body).to include("Marzo 2026")
      expect(response.body).to include("Producto para vista previa")
    end

    it "previews draft body from the editor" do
      import_lead_form_templates!(workspace)
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")

      post preview_lead_form_template_path(template), params: {
        lead_form_template: { body: "<div class=\"mx-auto max-w-xl\"><h1>Borrador</h1>{% form_open %}{% form_close %}</div>" }
      }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Incluye cambios sin guardar")
      expect(response.body).to include("Borrador")
    end

    it "shows preview link on index for pages only" do
      import_lead_form_templates!(workspace)

      get lead_form_templates_path

      expect(response.body).to include(preview_lead_form_template_path(
        workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")
      ))
      expect(response.body).not_to include(preview_lead_form_template_path(
        workspace.lead_form_templates.find_by!(path: "public/lead_forms/partials/contact_fields")
      ))
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

    it "forbids previewing templates" do
      template = workspace.lead_form_templates.create!(
        path: "public/lead_forms/demo",
        partial: false,
        body: "<p>demo</p>"
      )
      product = workspace.products.create!(name: "Ajeno", price: 1)

      get preview_lead_form_template_path(template, preview_product_id: product.id)

      expect(response).to redirect_to(root_path)
    end

    it "does not show Plantillas de formulario link on lead forms index" do
      get lead_forms_path

      expect(response.body).not_to include("Plantillas de formulario")
    end
  end
end
