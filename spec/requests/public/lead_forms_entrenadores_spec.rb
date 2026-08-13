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
      expect(response.body).to include(public_lead_form_privacy_path(lead_form.slug))
      expect(response.body).to include("CRM de Entaina")
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

    it "redirects to the configured success URL with lead data, omitting fields the form does not collect" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)
      lead_form.update!(success_redirect_url: "https://crm.example.com/b/reserva-jp")

      post public_lead_form_path(lead_form.slug), params: {
        lead: entrenadores_lead_params
      }

      location = URI.parse(response.headers["Location"])
      expect("#{location.scheme}://#{location.host}#{location.path}").to eq("https://crm.example.com/b/reserva-jp")
      query = Rack::Utils.parse_query(location.query)
      expect(query).to eq(
        "first_name" => "Ana",
        "last_name" => "García",
        "email" => "lead@example.com"
      )
      expect(query).not_to have_key("phone")
    end

    it "prefills from the submitted data, never from the stored CRM person" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)
      lead_form.update!(success_redirect_url: "https://crm.example.com/b/reserva-jp")
      company = workspace.companies.create!(name: "Particulares")
      workspace.people.create!(
        first_name: "Nombre", last_name: "Guardado", email: "lead@example.com",
        phone: "699999999", company: company
      )

      post public_lead_form_path(lead_form.slug), params: {
        lead: entrenadores_lead_params
      }

      # Si esto devolviera la ficha del CRM, cualquiera que conozca un email
      # podría pescar el nombre y teléfono almacenados de esa persona.
      query = Rack::Utils.parse_query(URI.parse(response.headers["Location"]).query)
      expect(query["first_name"]).to eq("Ana")
      expect(query["last_name"]).to eq("García")
      expect(query).not_to have_key("phone")
    end
  end
end
