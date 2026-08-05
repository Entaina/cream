require "rails_helper"

RSpec.describe LeadFormSubmissionProcessor do
  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) { create_lead_form!(workspace, user: member) }
  let(:request) { instance_double(ActionDispatch::Request, user_agent: "Mozilla/5.0", remote_ip: "203.0.113.1") }
  let(:qualified_stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }
  let(:proposal_stage) { pipeline.pipeline_stages.find_by!(name: "Proposal") }

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
      expect(result.deal.tasks.map(&:due_on)).to include(Date.current + 1.day)
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
    expect(existing.reload.first_name).to eq("Existente")
  end

  it "reuses an open deal in the target pipeline and merges submission data" do
    company = create_company!(workspace, name: "Acme SL")
    person = create_person!(workspace, company: company, email: "lead@example.com", first_name: "Existente", last_name: "")
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ], name: "Existing deal")
    submission = LeadSubmission.create!(
      workspace: workspace,
      lead_form: lead_form,
      deal: existing_deal,
      person: person,
      data: { "email" => "lead@example.com", "how_heard" => "evento" },
      metadata: { "lead_form_slug" => lead_form.slug, "submissions_at" => [ 1.day.ago.iso8601 ] }
    )

    expect {
      result = submit(contacto_lead_params("first_name" => "Otro", "last_name" => "Nuevo", "how_heard" => "otro", "message" => "Hola"))
      expect(result.deal).to eq(existing_deal)
      expect(result.submission.id).to eq(submission.id)
      expect(result.person.first_name).to eq("Existente")
      expect(result.person.last_name).to eq("Nuevo")
      expect(result.submission.data).to include("how_heard" => "evento", "message" => "Hola", "last_name" => "Nuevo")
      expect(result.deal.pipeline_stage).to eq(existing_deal.pipeline_stage)
    }.to change(Deal, :count).by(0)
      .and change(LeadSubmission, :count).by(0)
      .and change { submission.reload.metadata["submissions_at"].size }.by(1)
  end

  it "creates a new deal when the person only has closed deals in the target pipeline" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    won_stage = pipeline.pipeline_stages.find_by!(name: "Won")
    create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ], stage: won_stage)

    expect {
      submit(contacto_lead_params("how_heard" => "otro"))
    }.to change(Deal, :count).by(1)
      .and change(LeadSubmission, :count).by(1)
  end

  it "creates a new deal when the person has an open deal in another pipeline" do
    other_pipeline = pipeline.duplicate(name: "Other")
    other_pipeline.save!
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    create_deal!(workspace, pipeline: other_pipeline, company: company, contacts: [ person ])

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal.pipeline).to eq(pipeline)
    expect(person.deals.count).to eq(2)
  end

  it "silently discards resubmissions beyond the per-email daily cap on an existing open deal" do
    stub_const("LeadForm::MAX_SUBMISSIONS_PER_EMAIL_PER_DAY", 1)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ])

    expect(submit(contacto_lead_params)).to be_present

    expect {
      result = submit(contacto_lead_params("how_heard" => "otro"))
      expect(result).to be_nil
    }.to change(Deal, :count).by(0)
      .and change(LeadSubmission, :count).by(0)
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

  it "creates a new deal in the configured pipeline stage" do
    lead_form.update!(pipeline_stage: qualified_stage)

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal.pipeline_stage).to eq(qualified_stage)
  end

  it "advances a reused open deal to the configured stage and logs stage_changed" do
    lead_form.update!(pipeline_stage: qualified_stage)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ], stage: pipeline.first_stage)

    expect {
      result = submit(contacto_lead_params("how_heard" => "otro"))
      expect(result.deal).to eq(existing_deal)
      expect(result.deal.pipeline_stage).to eq(qualified_stage)
    }.to change { existing_deal.activities.where(action: "stage_changed").count }.by(1)
  end

  it "does not move a reused open deal backwards when it is already in a later stage" do
    lead_form.update!(pipeline_stage: qualified_stage)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ], stage: proposal_stage)

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal).to eq(existing_deal)
    expect(result.deal.pipeline_stage).to eq(proposal_stage)
  end

  it "keeps the deal stage when entry conditions are not met" do
    lead_form.update!(pipeline_stage: qualified_stage)
    workspace.stage_conditions.create!(
      pipeline_stage: qualified_stage,
      field: "value",
      operator: "gt",
      compare_value: "1000"
    )
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [ person ], stage: pipeline.first_stage, value: 0)

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal).to eq(existing_deal)
    expect(result.deal.reload.pipeline_stage).to eq(pipeline.first_stage)
    expect(result.submission).to be_present
  end

  it "creates the first task with the configured title and due days" do
    lead_form.update!(first_task_title: "Llamar al lead", first_task_due_days: 3)

    result = submit(contacto_lead_params("how_heard" => "otro"))

    task = result.deal.tasks.sole
    expect(task.title).to eq("Llamar al lead")
    expect(task.due_on).to eq(Date.current + 3.days)
    expect(task.assignee).to eq(lead_form.responsible)
  end

  it "creates the first task due today when configured with zero days" do
    lead_form.update!(first_task_due_days: 0)

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal.tasks.sole.due_on).to eq(Date.current)
  end

  it "uses the first stage of a routed pipeline when the configured stage belongs to the default pipeline" do
    cursos = pipeline.duplicate(name: "Cursos")
    cursos.save!
    lead_form.update!(pipeline_stage: qualified_stage, pipeline_routes: { "curso" => cursos.id })

    result = submit(contacto_lead_params("help_type" => "curso"))

    expect(result.deal.pipeline).to eq(cursos)
    expect(result.deal.pipeline_stage).to eq(cursos.first_stage)
  end
end
