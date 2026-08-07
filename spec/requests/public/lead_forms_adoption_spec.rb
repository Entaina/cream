require "rails_helper"

RSpec.describe "Public lead form Demo Adoption", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:proyectos) do
    copy = pipeline.duplicate(name: "Proyectos")
    copy.save!
    copy
  end
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "adoption",
      name: "Demo Adoption",
      template_key: "adoption",
      pipeline: proyectos,
      collects_company: false
    )
  end

  describe "GET /f/adoption" do
    it "renders the form fields" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Demo Adoption")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include("¿Dónde crees que está tu organización respecto a la IA")
      expect(response.body).to include("¿Cómo nos has conocido?")
      expect(response.body).to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/adoption" do
    it "creates a demo lead in the Proyectos pipeline and redirects to success" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: adoption_lead_params(
            organization_ia_stage: "Estamos probando con un equipo piloto",
            newsletter_opt_in: "1"
          )
        }
      }.to change(Deal, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      deal = Deal.order(:id).last
      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      expect(deal.pipeline).to eq(proyectos)
      expect(deal.name).to include("Demo Adoption")
      expect(deal.name).not_to include("(Demo)")
      expect(submission.data["organization_ia_stage"]).to eq("Estamos probando con un equipo piloto")
      expect(submission.data["how_heard"]).to eq("evento")
      expect(submission.data["newsletter_opt_in"]).to be(true)
      expect(person.company.name).to eq(LeadForm::PLACEHOLDER_COMPANY_NAME)
    end

    it "places the deal in the configured stage" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)
      demo_stage = proyectos.pipeline_stages.create!(
        name: "Demo",
        color: "hoki",
        probability: 10,
        position: proyectos.pipeline_stages.count,
        workspace: workspace
      )
      lead_form.update!(pipeline_stage: demo_stage)

      post public_lead_form_path(lead_form.slug), params: { lead: adoption_lead_params }

      deal = Deal.order(:id).last
      expect(deal.pipeline_stage).to eq(demo_stage)
    end

    it "rejects submission without phone" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: adoption_lead_params("phone" => "")
        }
      }.not_to change(Deal, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
