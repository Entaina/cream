require "rails_helper"

RSpec.describe "Public lead form Liderando con IA", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "liderando-ia",
      name: "Liderando con IA",
      template_key: "liderando_ia",
      collects_company: true
    )
  end

  describe "GET /f/liderando-ia" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Liderando con IA")
      expect(response.body).to include('name="lead[company_name]"')
      expect(response.body).not_to include('name="lead[job_title]"')
      expect(response.body).to include("¿Es para ti o para tu equipo?")
      expect(response.body).to include("Para mí")
      expect(response.body).to include("Para mi equipo")
      expect(response.body).not_to include("Solo para mí")
      expect(response.body).not_to include("¿Qué decisión sobre IA tenéis encima de la mesa ahora mismo?")
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include("LinkedIn")
      expect(response.body).to include("Google")
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).not_to match(/name="lead\[newsletter_opt_in\]"[^>]*checked/)
      expect(response.body).to include('href="/privacy"')
      expect(response.body).to include("CRM de Entaina")
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/liderando-ia" do
    it "creates a lead and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: liderando_ia_lead_params(newsletter_opt_in: "1")
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      expect(submission.data["audience"]).to eq("para_equipo")
      expect(submission.data["company_name"]).to eq("Acme SL")
      expect(submission.data["how_heard"]).to eq("linkedin")
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(person.job_title).to be_blank
      expect(person.company.name).to eq("Acme SL")
    end
  end
end
