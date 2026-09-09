require "rails_helper"

RSpec.describe "Lead forms", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:template) { create_email_template!(workspace, user: member) }

  before do
    sign_in_as(member)
    import_lead_form_templates!(workspace)
  end

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
            active: "1",
            success_redirect_url: "https://example.com/gracias"
          }
        }
      }.to change(LeadForm, :count).by(1)

      expect(response).to redirect_to(lead_forms_path)
      expect(LeadForm.last.collects_company).to be(true)
      expect(LeadForm.last.success_redirect_url).to eq("https://example.com/gracias")
    end

    it "creates a lead form without lead email template" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing sin email",
            slug: "landing-sin-email",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: "",
            active: "1"
          }
        }
      }.to change(LeadForm, :count).by(1)

      expect(response).to redirect_to(lead_forms_path)
      expect(LeadForm.find_by!(slug: "landing-sin-email").email_template).to be_nil
    end

    it "updates lead form to remove email template" do
      form = create_lead_form!(workspace, user: member, slug: "with-email")

      patch lead_form_path(form), params: { lead_form: { email_template_id: "" } }

      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.email_template).to be_nil
    end

    it "rejects an invalid success redirect URL" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing curso",
            slug: "landing-curso-invalid-url",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1",
            success_redirect_url: "javascript:alert(1)"
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates success redirect URL" do
      form = create_lead_form!(workspace, user: member, slug: "redirect-form")

      patch lead_form_path(form), params: {
        lead_form: { success_redirect_url: "https://example.com/thanks" }
      }

      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.success_redirect_url).to eq("https://example.com/thanks")
    end

    it "stores hidden field keys from textarea" do
      post lead_forms_path, params: {
        lead_form: {
          name: "Landing producto",
          slug: "landing-producto",
          template_key: "contacto",
          pipeline_id: pipeline.id,
          responsible_id: member.id,
          email_template_id: template.id,
          active: "1",
          hidden_field_keys_text: "producto\nlanding\nproducto"
        }
      }

      form = LeadForm.find_by!(slug: "landing-producto")
      expect(form.hidden_field_keys).to eq(%w[producto landing])
    end

    it "rejects reserved hidden field keys" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing reservado",
            slug: "landing-reservado",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1",
            hidden_field_keys_text: "utm_source"
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects invalid hidden field keys" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing invalido",
            slug: "landing-invalido",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1",
            hidden_field_keys_text: "1producto"
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "stores pipeline routes from parallel form fields" do
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
          pipeline_routes_submitted: "1",
          pipeline_route_keys: %w[curso entrenamiento],
          pipeline_route_pipeline_ids: [ cursos.id, pipeline.id ]
        }
      }

      form = LeadForm.find_by!(slug: "contacto")
      expect(form.pipeline_routes).to eq({ "curso" => cursos.id, "entrenamiento" => pipeline.id })
    end

    it "clears pipeline routes when all rows are removed" do
      form = create_lead_form!(workspace, user: member, slug: "routed-form")
      other = pipeline.duplicate(name: "Other")
      other.save!
      form.update!(pipeline_routes: { "curso" => other.id })

      patch lead_form_path(form), params: {
        lead_form: {
          pipeline_routes_submitted: "1",
          pipeline_route_keys: [],
          pipeline_route_pipeline_ids: []
        }
      }

      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.pipeline_routes).to eq({})
    end

    it "rejects invalid pipeline route keys" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Contacto",
            slug: "contacto-invalid-route",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1",
            pipeline_routes_submitted: "1",
            pipeline_route_keys: [ "Invalid-Key" ],
            pipeline_route_pipeline_ids: [ pipeline.id ]
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "creates a lead form with a pipeline stage" do
      qualified = pipeline.pipeline_stages.find_by!(name: "Qualified")

      post lead_forms_path, params: {
        lead_form: {
          name: "Landing etapa",
          slug: "landing-etapa",
          template_key: "contacto",
          pipeline_id: pipeline.id,
          pipeline_stage_id: qualified.id,
          responsible_id: member.id,
          email_template_id: template.id,
          active: "1"
        }
      }

      expect(response).to redirect_to(lead_forms_path)
      expect(LeadForm.find_by!(slug: "landing-etapa").pipeline_stage).to eq(qualified)
    end

    it "stores an optional product" do
      product = workspace.products.create!(name: "Curso ejemplo", price: 990)

      post lead_forms_path, params: {
        lead_form: {
          name: "Reserva",
          slug: "reserva-ejemplo",
          template_key: "reserva",
          pipeline_id: pipeline.id,
          responsible_id: member.id,
          email_template_id: template.id,
          product_id: product.id,
          active: "1"
        }
      }

      expect(response).to redirect_to(lead_forms_path)
      expect(LeadForm.find_by!(slug: "reserva-ejemplo").product).to eq(product)
    end

    it "rejects a pipeline stage from another pipeline" do
      other = pipeline.duplicate(name: "Other")
      other.save!
      foreign_stage = other.pipeline_stages.second

      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing etapa invalida",
            slug: "landing-etapa-invalida",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            pipeline_stage_id: foreign_stage.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1"
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates the pipeline stage" do
      form = create_lead_form!(workspace, user: member, slug: "stage-form")
      qualified = pipeline.pipeline_stages.find_by!(name: "Qualified")

      patch lead_form_path(form), params: { lead_form: { pipeline_stage_id: qualified.id } }

      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.pipeline_stage).to eq(qualified)
    end

    it "stores first task configuration" do
      post lead_forms_path, params: {
        lead_form: {
          name: "Landing tarea",
          slug: "landing-tarea",
          template_key: "contacto",
          pipeline_id: pipeline.id,
          responsible_id: member.id,
          email_template_id: template.id,
          active: "1",
          first_task_title: "Seguimiento inicial",
          first_task_due_days: "5"
        }
      }

      form = LeadForm.find_by!(slug: "landing-tarea")
      expect(form.first_task_title).to eq("Seguimiento inicial")
      expect(form.first_task_due_days).to eq(5)
    end

    it "rejects negative first task due days" do
      expect {
        post lead_forms_path, params: {
          lead_form: {
            name: "Landing tarea invalida",
            slug: "landing-tarea-invalida",
            template_key: "contacto",
            pipeline_id: pipeline.id,
            responsible_id: member.id,
            email_template_id: template.id,
            active: "1",
            first_task_title: "Seguimiento",
            first_task_due_days: "-1"
          }
        }
      }.not_to change(LeadForm, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates first task configuration" do
      form = create_lead_form!(workspace, user: member, slug: "task-form")

      patch lead_form_path(form), params: {
        lead_form: { first_task_title: "Contactar en 48h", first_task_due_days: "2" }
      }

      expect(response).to redirect_to(lead_forms_path)
      expect(form.reload.first_task_title).to eq("Contactar en 48h")
      expect(form.first_task_due_days).to eq(2)
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
