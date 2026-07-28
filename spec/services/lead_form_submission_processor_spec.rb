require "rails_helper"

RSpec.describe LeadFormSubmissionProcessor do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) { create_lead_form!(workspace, user: member) }
  let(:request) { instance_double(ActionDispatch::Request, user_agent: "Mozilla/5.0", remote_ip: "203.0.113.1") }

  def submit(params)
    described_class.call(lead_form:, params:, request:)
  end

  it "creates person, deal, submission and enqueues emails" do
    params = contacto_lead_params(
      "last_name" => "López",
      "newsletter_opt_in" => "0",
      "source_page" => "https://example.com/landing",
      "utm_source" => "newsletter",
      "how_heard" => "recomendacion"
    )

    expect {
      result = submit(params)
      expect(result.deal.pipeline_stage).to eq(pipeline.first_stage)
      expect(result.person.source).to eq("web_form")
      expect(result.person.company.name).to eq(LeadForm::PLACEHOLDER_COMPANY_NAME)
      expect(result.deal.tasks.map(&:title)).to include("Contactar lead")
      expect(result.submission.data).to include("email" => "lead@example.com", "how_heard" => "recomendacion", "help_type" => "curso")
      expect(result.submission.data["newsletter_opt_in"]).to be(false)
      expect(result.submission.metadata).to include(
        "lead_form_slug" => lead_form.slug,
        "lead_form_name" => lead_form.name,
        "utm_source" => "newsletter",
        "ip" => "203.0.113.1"
      )
    }.to change(Person, :count).by(1)
      .and change(Deal, :count).by(1)
      .and change(LeadSubmission, :count).by(1)
      .and change(EmailMessage, :count).by(1)
      .and change(Notification, :count).by(1)
      .and have_enqueued_job(SendViaGmailJob)
      .and have_enqueued_mail(LeadFormMailer, :responsible_notification)

    message = EmailMessage.order(:id).last
    expect(message.record).to eq(Deal.order(:id).last)
    expect(message.user).to eq(lead_form.responsible)
    expect(message.to_address).to eq("lead@example.com")

    notification = Notification.order(:id).last
    deal = Deal.order(:id).last
    expect(notification.user).to eq(lead_form.responsible)
    expect(notification.kind).to eq("lead_submission")
    expect(notification.url).to eq(Rails.application.routes.url_helpers.deal_path(deal))
  end

  it "silently discards submissions beyond the per-email daily cap" do
    stub_const("LeadForm::MAX_SUBMISSIONS_PER_EMAIL_PER_DAY", 1)
    submit(contacto_lead_params)

    expect {
      result = submit(contacto_lead_params)
      expect(result).to be_nil
    }.to change(Deal, :count).by(0)
      .and change(LeadSubmission, :count).by(0)
  end

  it "silently discards submissions beyond the per-form hourly cap" do
    stub_const("LeadForm::MAX_SUBMISSIONS_PER_FORM_PER_HOUR", 1)
    submit(contacto_lead_params)

    expect {
      result = submit(contacto_lead_params("email" => "otra@example.com"))
      expect(result).to be_nil
    }.to change(Deal, :count).by(0)
      .and change(LeadSubmission, :count).by(0)
  end

  it "routes contacto deals to the pipeline configured for the help type" do
    cursos = pipeline.duplicate(name: "Cursos")
    cursos.save!
    lead_form.update!(pipeline_routes: { "curso" => cursos.id })

    result = submit(contacto_lead_params("help_type" => "curso"))

    expect(result.deal.pipeline).to eq(cursos)
    expect(result.deal.name).to include("(Curso)")
  end

  it "reuses an existing person by email and keeps their company" do
    company = create_company!(workspace, name: "Acme SL")
    existing = create_person!(workspace, company: company, email: "lead@example.com", first_name: "Existente")

    expect {
      submit(contacto_lead_params("first_name" => "Otro", "how_heard" => "otro"))
    }.to change(Person, :count).by(0)
      .and change(Deal, :count).by(1)

    deal = Deal.order(:id).last
    expect(deal.contacts).to contain_exactly(existing)
    expect(deal.company).to eq(company)
  end

  it "uses placeholder company when the form does not collect company data" do
    submit(contacto_lead_params("email" => "solo@example.com", "first_name" => "Solo", "how_heard" => "otro"))

    person = Person.order(:id).last
    expect(person.company.name).to eq(LeadForm::PLACEHOLDER_COMPANY_NAME)
  end

  it "finds company by name when collecting company data" do
    lead_form.update!(template_key: "curso", collects_company: true)
    company = create_company!(workspace, name: "Acme SL")

    submit(
      contacto_lead_params(
        "email" => "ceo@acme.com",
        "first_name" => "CEO",
        "how_heard" => "busqueda",
        "company_name" => "Acme SL"
      ).except("help_type")
        .merge("qualifying_answer" => "IA")
    )

    deal = Deal.order(:id).last
    expect(deal.company).to eq(company)
  end

  it "finds company by CIF in fiscal information" do
    lead_form.update!(template_key: "curso", collects_company: true)
    company = workspace.companies.create!(name: "Fiscal Corp", fiscal_information: "B12345678")

    submit(
      contacto_lead_params(
        "email" => "fiscal@example.com",
        "first_name" => "Fiscal",
        "how_heard" => "evento",
        "company_name" => "Otro nombre",
        "company_cif" => "B12345678"
      ).except("help_type")
        .merge("qualifying_answer" => "IA")
    )

    deal = Deal.order(:id).last
    expect(deal.company).to eq(company)
  end
end
