require "rails_helper"

RSpec.describe "Public lead form Assessment · Índice de adopción", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "indice-adopcion-ia",
      name: "Assessment · Índice de adopción",
      template_key: "indice_adopcion_ia",
      collects_company: true
    )
  end

  describe "GET /f/indice-adopcion-ia" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Assessment · Índice de adopción")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include('name="lead[company_name]"')
      expect(response.body).to include('name="lead[job_title]"')
      expect(response.body).to include('name="lead[employee_range]"')
      expect(response.body).to include("Tamaño (nº de empleados)")
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/indice-adopcion-ia" do
    it "creates a lead and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: indice_adopcion_ia_lead_params(newsletter_opt_in: "1")
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      company = Company.order(:id).last
      expect(submission.data["employee_range"]).to eq("51-200")
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(person.job_title).to eq("Directora de innovación")
      expect(company.name).to eq("Acme SL")
      expect(company.employee_range).to eq("51-200")
    end

    it "rejects submission without phone" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: indice_adopcion_ia_lead_params("phone" => "")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects submission without company name" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: indice_adopcion_ia_lead_params("company_name" => "")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
