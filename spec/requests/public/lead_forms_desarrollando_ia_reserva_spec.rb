require "rails_helper"

RSpec.describe "Public lead form Desarrollando con IA — Reservas", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:product) { workspace.products.create!(name: "Desarrollando con IA", price: 990) }
  let!(:open_edition) { product.editions.create!(name: "Marzo 2026", ends_on: Date.current + 30.days) }
  let!(:second_edition) { product.editions.create!(name: "Junio 2026", ends_on: Date.current + 90.days) }
  let!(:finished_edition) { product.editions.create!(name: "Enero 2026", ends_on: Date.current - 1.day) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "desarrollando-con-ia-reservas",
      name: "Desarrollando con IA — Reservas",
      template_key: "desarrollando_ia_reserva",
      collects_company: false,
      product: product
    )
  end

  describe "GET /f/desarrollando-con-ia-reservas" do
    it "renders the form fields with edition buttons and phone prefix selector" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Desarrollando con IA — Reservas")
      expect(response.body).to include('name="lead[product_id]"')
      expect(response.body).to include('value="' + product.id.to_s + '"')
      expect(response.body).to include('name="lead[edition_id]"')
      expect(response.body).to include('type="radio"')
      expect(response.body).to include("Elige tu edición")
      expect(response.body).to include("Marzo 2026")
      expect(response.body).to include("Junio 2026")
      expect(response.body).not_to include("Enero 2026")
      expect(response.body).not_to include('<select name="lead[edition_id]"')
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[last_name]"')
      expect(response.body).to include("Apellidos")
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone_prefix]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include("¿En qué te podemos ayudar?")
      expect(response.body).not_to include('name="lead[how_heard]"')
      expect(response.body).not_to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include('href="/privacy"')
      expect(response.body).to include("CRM de Entaina")
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end
  end

  describe "POST /f/desarrollando-con-ia-reservas" do
    it "creates a lead with product, edition and prefixed phone on the deal" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: desarrollando_ia_reserva_lead_params(product: product, edition: open_edition)
        }
      }.to change(Deal, :count).by(1)
        .and change(DealProduct, :count).by(1)
        .and change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)
        .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

      expect(response).to redirect_to(public_lead_form_success_path(lead_form.slug))

      submission = LeadSubmission.order(:id).last
      person = Person.order(:id).last
      deal = Deal.order(:id).last
      line = deal.deal_products.first

      expect(submission.data["edition_id"]).to eq(open_edition.id.to_s)
      expect(submission.data["product_id"]).to eq(product.id.to_s)
      expect(submission.data["phone_prefix"]).to eq("+34")
      expect(submission.data["phone"]).to eq("600111222")
      expect(submission.data["message"]).to eq("Quiero reservar plaza")
      expect(person.last_name).to eq("García")
      expect(person.phone).to eq("+34 600111222")
      expect(person.company.name).to eq("Particulares")
      expect(line.product).to eq(product)
      expect(line.edition).to eq(open_edition)
    end
  end
end
