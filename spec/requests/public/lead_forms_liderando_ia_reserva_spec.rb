require "rails_helper"

RSpec.describe "Public lead form Liderando con IA — Reserva", type: :request do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:product) { workspace.products.create!(name: "Liderando con IA", price: 990) }
  let!(:open_edition) { product.editions.create!(name: "Marzo 2026", starts_on: Date.current + 30.days, ends_on: Date.current + 60.days) }
  let!(:finished_edition) { product.editions.create!(name: "Enero 2026", starts_on: Date.current - 30.days, ends_on: Date.current - 1.day) }
  let(:lead_form) do
    create_lead_form!(
      workspace,
      user: member,
      slug: "liderando-ia-reserva",
      name: "Liderando con IA — Reserva",
      template_key: "liderando_ia_reserva",
      collects_company: false,
      product: product
    )
  end

  describe "GET /f/liderando-ia-reserva" do
    it "renders the form fields with open editions from the configured product" do
      get public_lead_form_path(lead_form.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Liderando con IA — Reserva")
      expect(response.body).to include('name="lead[product_id]"')
      expect(response.body).to include('value="' + product.id.to_s + '"')
      expect(response.body).to include('name="lead[edition_id]"')
      expect(response.body).to include("Edición")
      expect(response.body).to include("Marzo 2026")
      expect(response.body).not_to include("Enero 2026")
      expect(response.body).to include('name="lead[first_name]"')
      expect(response.body).to include('name="lead[last_name]"')
      expect(response.body).to include("Apellidos")
      expect(response.body).to include('name="lead[email]"')
      expect(response.body).to include('name="lead[phone]"')
      expect(response.body).to include('name="lead[message]"')
      expect(response.body).not_to include('name="lead[how_heard]"')
      expect(response.body).not_to include('name="lead[newsletter_opt_in]"')
      expect(response.body).to include(public_lead_form_privacy_path(lead_form.slug))
      expect(response.body).to include("CRM de Entaina")
      expect(response.body).to include('name="lead[gdpr_consent]"')
    end

    it "allows overriding the product via query param" do
      other_product = workspace.products.create!(name: "Otro curso", price: 500)
      other_edition = other_product.editions.create!(name: "Septiembre 2026", starts_on: Date.current + 60.days)

      get public_lead_form_path(lead_form.slug, product_id: other_product.id)

      expect(response.body).to include('value="' + other_product.id.to_s + '"')
      expect(response.body).to include("Septiembre 2026")
      expect(response.body).not_to include("Marzo 2026")
    end
  end

  describe "POST /f/liderando-ia-reserva" do
    it "creates a lead with product and edition on the deal" do
      allow(TurnstileVerifier).to receive_messages(enabled?: false)

      expect {
        post public_lead_form_path(lead_form.slug), params: {
          lead: liderando_ia_reserva_lead_params(product: product, edition: open_edition)
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
      expect(submission.data["message"]).to eq("Quiero reservar plaza")
      expect(person.last_name).to eq("García")
      expect(person.company.name).to eq("Particulares")
      expect(line.product).to eq(product)
      expect(line.edition).to eq(open_edition)
    end
  end
end
