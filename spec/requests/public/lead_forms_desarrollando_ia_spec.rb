require "rails_helper"

RSpec.describe "Public lead form Desarrollando con IA", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "desarrollando-ia",
      name: "Desarrollando con IA",
      template_key: "desarrollando_ia",
      collects_company: false
    )
  end

  describe "GET /f/desarrollando-ia" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Desarrollando con IA")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include("Tu perfil técnico")
      expect(response.body).to include("Para ti o para tu equipo")
      expect(response.body).not_to include("¿Qué querrías construir o automatizar con IA en tu trabajo?")
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/desarrollando-ia" do
    it "creates a lead and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: desarrollando_ia_lead_params(newsletter_opt_in: "1")
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      expect(submission.data["tech_profile"]).to eq("desarrollo")
      expect(submission.data["audience"]).to eq("para_mi")
      expect(submission.data).not_to have_key("ia_build_automation")
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(person.company.name).to eq(LeadForm::PLACEHOLDER_COMPANY_NAME)
    end

    it "rejects submission without phone" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: desarrollando_ia_lead_params("phone" => "")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
