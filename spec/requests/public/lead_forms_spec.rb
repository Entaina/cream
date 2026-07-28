require "rails_helper"

RSpec.describe "Public lead forms", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) { create_lead_form!(workspace, user: member, slug: "contacto") }

  describe "GET /f/:slug" do
    it "renders the public form" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Contacto web")
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include("¿En qué te ayudamos?")
      expect(response.body).to include("Cuéntanos un poco más")
      expect(response.body).to include("newsletter de Example")
      expect(response.body).to include("beehiiv")
      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors *")
    end

    it "returns not found for inactive forms" do
      lead_form.update!(active: false)

      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /f/:slug" do
    it "creates a lead and redirects to success" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(
            help_type: "entrenamiento",
            newsletter_opt_in: "1",
            message: "Quiero saber más",
            source_page: "https://example.com",
            utm_source: "ads"
          )
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["help_type"]).to eq("entrenamiento")
      expect(submission.data["message"]).to eq("Quiero saber más")
    end

    it "rejects submissions without GDPR consent" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(gdpr_consent: "0")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("política de privacidad")
    end

    it "silently accepts honeypot submissions" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(email: "bot@example.com", LeadForm::HONEYPOT_FIELD => "spam")
        }
      }.not_to change(Deal, :count)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))
    end

    it "silently discards submissions faster than the time-trap" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(LeadForm::TIMESTAMP_FIELD => LeadForm.signed_timestamp)
        }
      }.not_to change(Deal, :count)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))
    end

    it "silently discards submissions without a valid time-trap token" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(LeadForm::TIMESTAMP_FIELD => "forged")
        }
      }.not_to change(Deal, :count)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))
    end

    it "rejects submissions when Turnstile is enabled and verification fails" do
      allow(TurnstileVerifier).to receive_messages(enabled?: true, valid?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params, "cf-turnstile-response" => "bad-token"
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("verificar que eres una persona")
      expect(TurnstileVerifier).to have_received(:valid?).with(token: "bad-token", ip: anything)
    end

    it "re-renders the form when validation fails" do
      post public_lead_form_path(lead_form.slug), params: {
        lead: contacto_lead_params(email: "")
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Contacto web")
    end
  end
end
