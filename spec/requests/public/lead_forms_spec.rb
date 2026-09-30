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
      expect(response.body).to include('name="lead[subscribe_all]"')
      expect(response.body).to include("beehiiv")
      expect(response.body).to include(public_lead_form_privacy_path(lead_form.slug))
      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors *")
      expect(response.body).to include('name="lead[privacy_policy_hash]"')
    end

    it "embeds the privacy policy hash from the captured version" do
      get public_lead_form_path(lead_form.slug)

      version = PrivacyPolicyVersion.find_by!(workspace: workspace)
      expect(response.body).to include(%(value="#{version.content_hash}"))
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
      slug = lead_form.slug
      LeadFormTemplate.delete_all

      get public_lead_form_path(slug)

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

  describe "GET /f/:slug/privacy" do
    it "renders the workspace privacy template" do
      get public_lead_form_privacy_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Política de privacidad")
      expect(response.body).to include("Responsable del tratamiento")
      expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors *")
    end

    it "reflects workspace template edits" do
      workspace.lead_form_templates.find_by!(path: "public/lead_forms/privacy").update!(
        body: '<div class="mx-auto max-w-xl"><p id="privacy-marker">Política personalizada</p></div>'
      )

      get public_lead_form_privacy_path(lead_form.slug)

      expect(response.body).to include("Política personalizada")
    end

    it "returns not found when workspace templates are not imported" do
      slug = lead_form.slug
      LeadFormTemplate.delete_all

      get public_lead_form_privacy_path(slug)

      expect(response).to have_http_status(:not_found)
    end

    it "returns not found for inactive forms" do
      lead_form.update!(active: false)

      get public_lead_form_privacy_path(lead_form.slug)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /f/:slug" do
    it "creates a lead and redirects to success" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params_with_privacy(
            lead_form,
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

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["help_type"]).to eq("entrenamiento")
      expect(submission.data["message"]).to eq("Quiero saber más")
      expect(submission.privacy_policy_version).to be_present
      expect(submission.metadata["privacy_policy_url"]).to include("/f/#{lead_form.slug}/privacy")
      subscription = EmailSubscription.order(:id).last
      expect(subscription.metadata["privacy_policy_version_id"]).to eq(submission.privacy_policy_version_id)
    end

    it "subscribes to all active types when subscribe_all is checked" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)

      active_count = workspace.subscription_types.active.count

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params_with_privacy(
            lead_form,
            subscribe_all: "1",
            subscribe_all_label: "Quiero todas las comunicaciones"
          )
        }
      }.to change(EmailSubscription, :count).by(active_count)

      submission = LeadSubmission.order(:id).last
      expect(submission.data["subscribe_all"]).to be(true)

      person = Person.find_by!(email: "lead@example.com")
      workspace.subscription_types.active.find_each do |type|
        subscription = EmailSubscription.find_by!(person: person, subscription_type: type)
        expect(subscription.status).to eq("subscribed")
        expect(subscription.metadata["subscribe_all"]).to be(true)
        expect(subscription.metadata["subscribe_all_label"]).to eq("Quiero todas las comunicaciones")
      end
    end

    it "skips types excluded from subscribe_all on public submit" do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)

      excluded = workspace.subscription_types.find_by!(slug: "events")
      excluded.update!(excluded_from_subscribe_all: true)
      included_count = workspace.subscription_types.included_in_subscribe_all.count

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params_with_privacy(lead_form, subscribe_all: "1")
        }
      }.to change(EmailSubscription, :count).by(included_count)

      person = Person.find_by!(email: "lead@example.com")
      expect(EmailSubscription.find_by(person: person, subscription_type: excluded)).to be_nil
      workspace.subscription_types.included_in_subscribe_all.find_each do |type|
        expect(EmailSubscription.find_by!(person: person, subscription_type: type).status).to eq("subscribed")
      end
    end

    it "creates a new privacy policy version when the policy template changes" do
      first_hash = privacy_policy_hash_for(lead_form)
      workspace.lead_form_templates.find_by!(path: PrivacyPolicyVersion::POLICY_PATH).update!(
        body: '<div class="mx-auto max-w-xl"><p id="privacy-marker">Política v2</p></div>'
      )
      second_hash = privacy_policy_hash_for(lead_form)

      expect(second_hash).not_to eq(first_hash)
      expect(PrivacyPolicyVersion.where(workspace: workspace).count).to eq(2)
    end

    it "redirects to configured success URL with lead data as query params" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      post public_lead_form_path(lead_form.slug), params: {
        lead: contacto_lead_params
      }

      location = URI.parse(response.headers["Location"])
      expect("#{location.scheme}://#{location.host}#{location.path}").to eq("https://example.com/gracias")
      expect(Rack::Utils.parse_query(location.query)).to eq(
        "first_name" => "Ana",
        "last_name" => "García",
        "email" => "lead@example.com",
        "phone" => "600111222"
      )
    end

    it "keeps query params already present in the configured success URL" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias?utm_source=crm&first_name=Fijado")

      post public_lead_form_path(lead_form.slug), params: {
        lead: contacto_lead_params
      }

      location = URI.parse(response.headers["Location"])
      query = Rack::Utils.parse_query(location.query)
      expect(query["utm_source"]).to eq("crm")
      # Ante colisión gana lo configurado a mano en la URL, no el dato del lead.
      expect(query["first_name"]).to eq("Fijado")
      expect(query["email"]).to eq("lead@example.com")
    end

    it "does not append lead data when the submission is suspected to be a bot" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(LeadForm::HONEYPOT_FIELD => "spam")
        }
      }.not_to change(Deal, :count)

      # El camino de bots redirige sin crear lead: la URL debe ir limpia, sin datos.
      expect(response).to redirect_to("https://example.com/gracias")
    end

    it "uses target _top when success redirect URL is configured" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      get public_lead_form_path(lead_form.slug)

      expect(response.body).to include('target="_top"')
    end

    it "opts out of Turbo when success redirect URL is configured, so target _top applies" do
      lead_form.update!(success_redirect_url: "https://example.com/gracias")

      get public_lead_form_path(lead_form.slug)

      # Turbo intercepta el submit y lo manda por fetch, ignorando el target: embebido en
      # otra web el lead se crea pero el visitante nunca llega al destino de la redirección.
      expect(response.body).to include('data-turbo="false"')
    end

    it "keeps Turbo enabled when there is no success redirect URL" do
      get public_lead_form_path(lead_form.slug)

      expect(response.body).not_to include('data-turbo="false"')
    end

    it "stores configured hidden URL fields and ignores undeclared params" do
      lead_form.update!(hidden_field_keys: %w[producto])

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(producto: "curso-ia", extra_field: "custom-value")
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

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("política de privacidad")
    end

    it "silently accepts honeypot submissions" do
      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params(:email => "bot@example.com", LeadForm::HONEYPOT_FIELD => "spam")
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
          :lead => contacto_lead_params, "cf-turnstile-response" => "bad-token"
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("verificar que eres una persona")
      expect(response.body).to include('role="alert"')
      expect(response.body).to include('value="Ana"')
      expect(TurnstileVerifier).to have_received(:valid?).with(token: "bad-token", ip: anything)
    end

    it "re-renders the form when validation fails" do
      post public_lead_form_path(lead_form.slug), params: {
        lead: contacto_lead_params(email: "")
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Contacto web")
    end

    it "rejects free email when corporate email is required" do
      lead_form.update!(require_corporate_email: true)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params("email" => "ana@gmail.com")
        }
      }.not_to change(Person, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("email corporativo")
      expect(response.body).to include('role="alert"')
    end
  end

  describe "POST /f/:slug for an MQL form" do
    let(:lead_form) do
      create_lead_form!(workspace, user: member, slug: "mql-contacto", destination: "mql", pipeline: nil)
    end

    before do
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:mql_pool).and_return(true)
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
    end

    it "accepts the submission key rendered on the form" do
      key = submission_key_for(lead_form)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: contacto_lead_params_with_privacy(lead_form, "_submission_key" => key)
        }
      }.to change(LeadSubmission, :count).by(1)
        .and change(Deal, :count).by(0)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))
      expect(LeadSubmission.order(:id).last.submission_key).to eq(key)
    end
  end

  describe "GET /f/:slug with corporate email" do
    it "embeds Stimulus values when corporate email is required" do
      lead_form.update!(require_corporate_email: true)

      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-lead-form-require-corporate-email-value="true"')
      expect(response.body).to include("gmail.com")
      expect(response.body).to include("validateCorporateEmail")
    end

    it "does not embed corporate email Stimulus values when disabled" do
      get public_lead_form_path(lead_form.slug)

      expect(response.body).not_to include('data-lead-form-require-corporate-email-value="true"')
    end
  end
end
