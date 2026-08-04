require "rails_helper"

RSpec.describe "Public lead form Liderando con IA — Reserva", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "liderando-ia-reserva",
      name: "Liderando con IA — Reserva",
      template_key: "liderando_ia_reserva",
      collects_company: false
    )
  end

  describe "GET /f/liderando-ia-reserva" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Liderando con IA — Reserva")
      expect(response.body).to include('name="lead[edition]"')
      expect(response.body).to include("Edición")
      expect(response.body).to include("Marzo 2026")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[last_name]"')
      expect(response.body).to include("Apellidos")
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include('name="lead[message]"')
      expect(response.body).not_to include('name="lead[how_heard]"')
      expect(response.body).not_to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include("https://entaina.ai/privacy-policy")
      expect(response.body).to include("Mis datos se guardan en CReaM, el CRM de entaina")
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/liderando-ia-reserva" do
    it "creates a lead and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: liderando_ia_reserva_lead_params
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      expect(submission.data["edition"]).to eq("marzo_2026")
      expect(submission.data["message"]).to eq("Quiero reservar plaza")
      expect(person.last_name).to eq("García")
      expect(person.company.name).to eq("Particulares")
    end
  end
end
