require "rails_helper"

RSpec.describe "Public lead form Trabajando con IA", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "trabajando-ia",
      name: "Trabajando con IA",
      template_key: "trabajando_ia",
      collects_company: false
    )
  end

  describe "GET /f/trabajando-ia" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Trabajando con IA")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include("¿Qué tarea de tu trabajo te gustaría resolver con IA y hoy no sabes?")
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/trabajando-ia" do
    it "creates a lead and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: trabajando_ia_lead_params(
            ia_work_task: "Automatizar el seguimiento de propuestas comerciales",
            newsletter_opt_in: "1"
          )
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      expect(submission.data["ia_work_task"]).to eq("Automatizar el seguimiento de propuestas comerciales")
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(person.company.name).to eq(LeadForm::PLACEHOLDER_COMPANY_NAME)
    end

    it "rejects submission without phone" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: trabajando_ia_lead_params("phone" => "")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
