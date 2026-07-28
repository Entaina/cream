require "rails_helper"

RSpec.describe "Lead forms", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:template) { create_email_template!(workspace, user: member) }

  before { sign_in_as(member) }

  describe "CRUD" do
    it "lists lead forms" do
      create_lead_form!(workspace, user: member, slug: "listed")

      get lead_forms_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("listed")
      expect(response.body).to include("/f/listed")
      expect(response.body).to include('data-controller="clipboard"')
      expect(response.body).to include('aria-readonly="true"')
      expect(response.body).to include("Copiar al portapapeles")
      expect(response.body).to include('data-clipboard-target="feedback"')
    end

    it "creates a lead form" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing curso",
            slug: "landing-curso",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            collects_company: "1",
            active: "1"
          }
        }
      }.to change(LeadForm, :count).by(1)

      expect(response).to redirect_to(lead_forms_path)
      expect(LeadForm.last.collects_company).to be(true)
    end

    it "stores pipeline routes for contacto forms" do
      cursos = pipeline.duplicate(name: "Cursos")
      cursos.save!

      post lead_forms_path, params: {
        lead_form: {
          name: "Contacto",
          slug: "contacto",
          template_key: "contacto",
          pipeline_id: pipeline.id,
          responsible_id: member.id,
          email_template_id: template.id,
          active: "1",
          pipeline_routes: { curso: cursos.id, entrenamiento: pipeline.id }
        }
      }

      form = LeadForm.find_by!(slug: "contacto")
      expect(form.pipeline_routes).to eq({ "curso" => cursos.id, "entrenamiento" => pipeline.id })
    end

    it "updates and deletes a lead form" do
      form = create_lead_form!(workspace, user: member, slug: "editable")

      patch lead_form_path(form), params: { lead_form: { name: "Nuevo nombre", active: "0" } }
      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.name).to eq("Nuevo nombre")

      expect {
        delete lead_form_path(form)
      }.to change(LeadForm, :count).by(-1)
    end
  end
end
