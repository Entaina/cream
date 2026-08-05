require "rails_helper"

RSpec.describe "Public lead form Entrenadores", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) do
    Pipeline.create_default!(workspace).duplicate(name: "Entrenadores").tap(&:save!)
  end
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      pipeline: pipeline,
      slug: "entrenadores",
      name: "Entrenadores",
      template_key: "entrenadores"
    )
  end

  describe "GET /f/entrenadores" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Entrenadores")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).not_to include('name="lead[phone]"')
      expect(response.body).not_to include("¿Cómo nos has conocido?")
      expect(response.body).to include("¿Cuál está siendo tu principal reto con la IA?")
      expect(response.body).to include('name="lead[message]"')
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).not_to match(/name="lead\[newsletter_opt_in\]"[^>]*checked/)
      expect(response.body).to include("https://entaina.ai/privacy-policy")
      expect(response.body).to include("Mis datos se guardan en CReaM, el CRM de Entaina")
      expect(response.body).to include("beehiiv")
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/entrenadores" do
    it "creates a lead without phone and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: entrenadores_lead_params("message" => "Integrar IA en mis sesiones de formación")
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      deal = Deal.order(:id).last
      expect(submission.data["message"]).to eq("Integrar IA en mis sesiones de formación")
      expect(submission.data).not_to have_key("phone")
      expect(deal.pipeline).to eq(pipeline)
    end
  end
end
