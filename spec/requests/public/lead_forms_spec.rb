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
      expect(response.body).to include("newsletter de Entaina")
      expect(response.body).to include("beehiiv")
      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors *")
    end

    it "returns not found for inactive forms" do
      lead_form.update!(active: false)

      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "renders configured hidden fields from query params" do
      lead_form.update!(hidden_field_keys: %w[producto landing])

      get public_lead_form_path(lead_form.slug, producto: "curso-ia", landing: "home")

      expect(response.body).to include('name="lead[producto]"')
      expect(response.body).to include('value="curso-ia"')
      expect(response.body).to include('name="lead[landing]"')
      expect(response.body).to include('value="home"')
      expect(response.body).to include('data-lead-form-param="producto"')
    end

    it "returns not found when workspace templates are not imported" do
      LeadFormTemplate.delete_all

      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:not_found)
    end

    it "renders workspace templates from the database" do
      workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto").update!(
        body: '<div class="mx-auto max-w-xl"><p id="db-template-marker">DB template override</p></div>'
      )

      get public_lead_form_path(lead_form.slug)

      expect(response.body).to include("DB template override")
      expect(response.body).not_to include("¿En qué te ayudamos?")
    end

    it "reflects template edits without restarting the app" do
      template = workspace.lead_form_templates.find_by!(path: "public/lead_forms/contacto")
      template.update!(body: '<div class="mx-auto max-w-xl"><p id="db-template-marker">Version one</p></div>')

      get public_lead_form_path(lead_form.slug)
      expect(response.body).to include("Version one")

      template.update!(body: '<p id="db-template-marker">Version two</p>')

      get public_lead_form_path(lead_form.slug)
      expect(response.body).to include("Version two")
      expect(response.body).not_to include("Version one")
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

    it "redirects to configured success URL when present" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      post public_lead_form_path(lead_form.slug), params: {
        lead: contacto_lead_params
      }

      expect(response).to redirect_to("https://example.com/gracias")
    end

    it "uses target _top when success redirect URL is configured" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      get public_lead_form_path(lead_form.slug)

      expect(response.body).to include('target="_top"')
    end

    it "stores configured hidden field values in submission data" do
      lead_form.update!(hidden_field_keys: %w[producto])

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(producto: "curso-ia", extra_field: "ignored")
        }
      }.to change(Deal, :count).by(1)

      submission = LeadSubmission.order(:id).last
      expect(submission.data["producto"]).to eq("curso-ia")
      expect(submission.data).not_to have_key("extra_field")
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
