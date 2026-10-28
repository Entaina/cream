require "rails_helper"

RSpec.describe LeadFormSubmissionProcessor do
  include ActiveSupport::Testing::TimeHelpers

  fixtures :users, :workspaces, :memberships

  let(:member) { users(:one) }
  let(:workspace) { workspaces(:one) }
  let!(:pipeline) { Pipeline.create_default!(workspace) }
  let(:lead_form) { create_lead_form!(workspace, user: member, pipeline: pipeline) }
  let(:request) do
    cookie_jar = ActiveSupport::InheritableOptions.new
    instance_double(
      ActionDispatch::Request,
      user_agent: "Mozilla/5.0",
      remote_ip: "203.0.113.1",
      cookie_jar: cookie_jar
    )
  end
  let(:qualified_stage) { pipeline.pipeline_stages.find_by!(name: "Qualified") }
  let(:proposal_stage) { pipeline.pipeline_stages.find_by!(name: "Proposal") }

  before { import_lead_form_templates!(workspace) }

  def submit(params)
    described_class.call(lead_form:, params:, request:)
  end

  it "rejects submissions without required fields from the rendered template" do
    expect {
      submit(contacto_lead_params("last_name" => ""))
    }.to raise_error(ActiveRecord::RecordInvalid, /#{Regexp.escape(Person.human_attribute_name(:last_name))} can't be blank/)
  end

  it "links privacy policy version to submission when hash is present" do
    version = Marketing::ConsentPolicySnapshot.capture(
      workspace: workspace,
      policy_html: "<p>Policy</p>",
      statement_html: "<p>Statement</p>"
    )
    params = contacto_lead_params("privacy_policy_hash" => version.content_hash)

    result = submit(params)

    expect(result.submission.privacy_policy_version).to eq(version)
    expect(result.submission.metadata["privacy_policy_hash"]).to eq(version.content_hash)
    expect(result.submission.metadata["privacy_policy_url"]).to be_present
  end

  it "labels the activities it records with the form name" do
    result = submit(contacto_lead_params)

    expect(result.person.reload.lifecycle_stage).to eq("lead")
    automation = {"kind" => "form", "name" => lead_form.name}
    lifecycle = result.person.activities.where(action: "updated").detect { |a| a.metadata["changes"]&.key?("lifecycle_stage") }
    expect(lifecycle.user).to be_nil
    expect(lifecycle.metadata["automation"]).to eq(automation)
    expect(result.deal.activities.find_by!(action: "created").metadata["automation"]).to eq(automation)
    expect(Current.automation).to be_nil
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

  it "emails the responsible when they enabled the email channel" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: true)

    expect {
      submit(contacto_lead_params)
    }.to have_enqueued_mail(LeadFormMailer, :responsible_notification)
      .and change(Notification, :count).by(0)
  end

  it "skips responsible notification when they disabled all channels" do
    memberships(:one_one).update!(alert_in_app: false, alert_email: false)

    expect {
      submit(contacto_lead_params)
    }.to change(Notification, :count).by(0)
      .and have_enqueued_mail(LeadFormMailer, :responsible_notification).exactly(0).times
  end

  it "interpolates form config and submission data into the lead email template" do
    template = create_email_template!(
      workspace,
      user: member,
      subject: "Gracias por contactar con {form_name}",
      body: "Hola {first_name}, tu consulta sobre {help_type}: {message}."
    )
    lead_form.update!(email_template: template, name: "Formulario contacto")

    expect {
      submit(contacto_lead_params(
        "help_type" => "curso",
        "message" => "Quiero más info"
      ))
    }.to change(EmailMessage, :count).by(1)
      .and have_enqueued_job(SendViaGmailJob)

    message = EmailMessage.order(:id).last
    expect(message.subject).to eq("Gracias por contactar con Formulario contacto")
    expect(message.body).to eq("Hola Ana, tu consulta sobre curso: Quiero más info.")
  end

  it "escapes HTML typed by the visitor in the lead email" do
    template = create_email_template!(workspace, user: member, subject: "Gracias", body: "<p>Hola {first_name}: {message}</p>")
    lead_form.update!(email_template: template)

    submit(contacto_lead_params("first_name" => "<b>Ana</b>", "message" => "<a href=\"https://evil.test\">premio</a>"))

    body = EmailMessage.order(:id).last.body
    expect(body).not_to include("<a href", "<b>")
    expect(body).to include("&lt;a href=&quot;https://evil.test&quot;&gt;premio&lt;/a&gt;")
  end

  it "attaches email template files to the lead confirmation message" do
    template = create_email_template!(
      workspace,
      user: member,
      subject: "Gracias",
      body: "Hola {first_name}"
    )
    template.attachments.attach(
      io: StringIO.new("brochure content"),
      filename: "brochure.pdf",
      content_type: "application/pdf"
    )
    lead_form.update!(email_template: template)

    submit(contacto_lead_params)

    message = EmailMessage.order(:id).last
    expect(message.attachments.count).to eq(1)
    expect(message.attachments.first.filename.to_s).to eq("brochure.pdf")
  end

  it "interpolates empty form fields as blank strings in the lead email template" do
    template = create_email_template!(
      workspace,
      user: member,
      subject: "Gracias {first_name}",
      body: "Mensaje: «{message}»"
    )
    lead_form.update!(email_template: template)

    submit(contacto_lead_params("message" => ""))

    message = EmailMessage.order(:id).last
    expect(message.body).to eq("Mensaje: «»")
  end

  it "does not enqueue lead email when the form has no email template" do
    lead_form.update!(email_template: nil)

    expect {
      submit(contacto_lead_params("how_heard" => "otro"))
    }.to change(Person, :count).by(1)
      .and change(Deal, :count).by(1)
      .and change(LeadSubmission, :count).by(1)
      .and change(EmailMessage, :count).by(0)
      .and change(Notification, :count).by(1)
      .and have_enqueued_job(SendViaGmailJob).exactly(0).times
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
    lead_form.update!(pipeline_routes: {"curso" => cursos.id})

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

  it "reuses an open deal in the target pipeline and creates a new submission and task" do
    company = create_company!(workspace, name: "Acme SL")
    person = create_person!(workspace, company: company, email: "lead@example.com", first_name: "Existente", last_name: "")
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], name: "Existing deal")
    existing_deal.tasks.create!(
      title: "Tarea previa",
      due_on: Date.current,
      workspace: workspace,
      user: member,
      assignee: member
    )
    submission = LeadSubmission.create!(
      workspace: workspace,
      lead_form: lead_form,
      deal: existing_deal,
      person: person,
      data: {"email" => "lead@example.com", "how_heard" => "evento"},
      metadata: {"lead_form_slug" => lead_form.slug, "submissions_at" => [1.day.ago.iso8601]}
    )

    expect {
      result = submit(contacto_lead_params("first_name" => "Otro", "last_name" => "Nuevo", "how_heard" => "otro", "message" => "Hola"))
      expect(result.deal).to eq(existing_deal)
      expect(result.submission.id).not_to eq(submission.id)
      expect(result.person.first_name).to eq("Existente")
      expect(result.person.last_name).to eq("Nuevo")
      expect(result.submission.data).to include("how_heard" => "otro", "message" => "Hola", "last_name" => "Nuevo")
      expect(submission.reload.data).to include("how_heard" => "evento")
      expect(result.deal.pipeline_stage).to eq(existing_deal.pipeline_stage)
      expect(result.deal.tasks.map(&:title)).to include("Contactar lead")
    }.to change(Deal, :count).by(0)
      .and change(LeadSubmission, :count).by(1)
      .and change(Task, :count).by(1)
  end

  it "creates a new deal when the person only has closed deals in the target pipeline" do
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    won_stage = pipeline.pipeline_stages.find_by!(name: "Won")
    create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], stage: won_stage)

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
    create_deal!(workspace, pipeline: other_pipeline, company: company, contacts: [person])

    result = submit(contacto_lead_params("how_heard" => "otro"))

    expect(result.deal.pipeline).to eq(pipeline)
    expect(person.deals.count).to eq(2)
  end

  it "silently discards resubmissions beyond the per-email daily cap on an existing open deal" do
    stub_const("LeadForm::MAX_SUBMISSIONS_PER_EMAIL_PER_DAY", 1)
    company = create_company!(workspace)
    person = create_person!(workspace, company: company, email: "lead@example.com")
    create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person])

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

  it "links anonymous page views to the person when cream_aid is present" do
    allow(CreamFeatures).to receive(:enabled?).and_call_original
    allow(CreamFeatures).to receive(:enabled?).with(:web_tracking).and_return(true)
    anonymous_id = "anon-123"
    workspace.page_views.create!(
      anonymous_id: anonymous_id,
      url: "https://example.com/pricing",
      occurred_at: Time.current
    )

    submit(contacto_lead_params("cream_aid" => anonymous_id))

    person = Person.order(:id).last
    expect(workspace.page_views.where(anonymous_id: anonymous_id).pluck(:person_id)).to eq([person.id])
  end

  it "finds company by name when collecting company data" do
    lead_form.update!(template_key: "demo", collects_company: true)
    company = create_company!(workspace, name: "Acme SL")

    submit(
      demo_lead_params(
        "email" => "ceo@acme.com",
        "first_name" => "CEO",
        "company_name" => "Acme SL"
      )
    )

    deal = Deal.order(:id).last
    expect(deal.company).to eq(company)
  end

  it "rejects company_cif when the rendered form does not include that field" do
    lead_form.update!(template_key: "demo", collects_company: true)

    expect {
      submit(demo_lead_params("company_cif" => "B12345678"))
    }.to raise_error(ActiveRecord::RecordInvalid, /Unknown field company_cif/)
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
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], stage: pipeline.first_stage)

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
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], stage: proposal_stage)

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
    existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person], stage: pipeline.first_stage, value: 0)

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

  it "creates the first task with due date relative to deal creation, not form configuration date" do
    lead_form.update!(first_task_due_days: 2)
    submission_day = Date.new(2026, 8, 10)

    travel_to submission_day.noon do
      result = submit(contacto_lead_params("how_heard" => "otro"))
      expect(result.deal.tasks.sole.due_on).to eq(Date.new(2026, 8, 12))
    end
  end

  it "uses the first stage of a routed pipeline when the configured stage belongs to the default pipeline" do
    cursos = pipeline.duplicate(name: "Cursos")
    cursos.save!
    lead_form.update!(pipeline_stage: qualified_stage, pipeline_routes: {"curso" => cursos.id})

    result = submit(contacto_lead_params("help_type" => "curso"))

    expect(result.deal.pipeline).to eq(cursos)
    expect(result.deal.pipeline_stage).to eq(cursos.first_stage)
  end

  describe "product and edition attachment" do
    let(:product) { workspace.products.create!(name: "Curso ejemplo", price: 990) }
    let(:edition) { product.editions.create!(name: "Marzo 2026", starts_on: Date.current + 30.days, ends_on: Date.current + 60.days) }
    let(:lead_form) do
      create_lead_form!(
        workspace,
        user: member,
        pipeline: pipeline,
        template_key: "reserva",
        product: product,
        slug: "reserva-#{SecureRandom.hex(3)}"
      )
    end

    def reserva_params(overrides = {})
      reserva_lead_params(product: product, edition: edition, **overrides)
    end

    it "creates a deal product line when the form has a configured product and edition" do
      result = submit(reserva_params)

      line = result.deal.deal_products.sole
      expect(line.product).to eq(product)
      expect(line.edition).to eq(edition)
      expect(line.quantity).to eq(1)
      expect(result.submission.data).to include(
        "product_id" => product.id.to_s,
        "edition_id" => edition.id.to_s
      )
    end

    it "interpolates product and edition into the lead email template" do
      template = create_email_template!(
        workspace,
        user: member,
        subject: "Reserva {product}",
        body: "Edición: {edition}"
      )
      lead_form.update!(email_template: template)

      expect {
        submit(reserva_params)
      }.to change(EmailMessage, :count).by(1)
        .and have_enqueued_job(SendViaGmailJob)

      message = EmailMessage.order(:id).last
      expect(message.subject).to eq("Reserva Curso ejemplo")
      expect(message.body).to eq("Edición: Marzo 2026")
    end

    it "overrides the configured product with the submitted product_id param" do
      configured = workspace.products.create!(name: "Configured", price: 100)
      override = workspace.products.create!(name: "Override", price: 200)
      override_edition = override.editions.create!(name: "Override edition", starts_on: Date.current + 30.days, ends_on: Date.current + 60.days)
      lead_form.update!(product: configured)

      result = submit(reserva_lead_params(
        product: override,
        edition: override_edition
      ))

      expect(result.deal.deal_products.sole.product).to eq(override)
    end

    it "does not duplicate the same product and edition when reusing an open deal" do
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "lead@example.com")
      existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person])
      existing_deal.deal_products.create!(product: product, edition: edition, quantity: 1)

      expect {
        result = submit(reserva_params)
        expect(result.deal).to eq(existing_deal)
      }.not_to change(DealProduct, :count)
    end

    it "updates the edition when reusing an open deal with the same product and a different edition" do
      other_edition = product.editions.create!(name: "Abril 2026", starts_on: Date.current + 90.days, ends_on: Date.current + 120.days)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "lead@example.com")
      existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person])
      line = existing_deal.deal_products.create!(product: product, edition: edition, quantity: 1)

      expect {
        result = submit(reserva_lead_params(product: product, edition: other_edition))
        expect(result.deal).to eq(existing_deal)
      }.not_to change(DealProduct, :count)

      expect(line.reload.edition).to eq(other_edition)
    end

    it "adds a new line when reusing an open deal with a different product" do
      other_product = workspace.products.create!(name: "Otro producto", price: 500)
      other_edition = other_product.editions.create!(name: "Junio 2026", starts_on: Date.current + 30.days, ends_on: Date.current + 60.days)
      company = create_company!(workspace)
      person = create_person!(workspace, company: company, email: "lead@example.com")
      existing_deal = create_deal!(workspace, pipeline: pipeline, company: company, contacts: [person])
      existing_deal.deal_products.create!(product: product, edition: edition, quantity: 1)

      expect {
        result = submit(reserva_lead_params(product: other_product, edition: other_edition))
        expect(result.deal).to eq(existing_deal)
      }.to change(DealProduct, :count).by(1)

      expect(existing_deal.deal_products.pluck(:product_id)).to contain_exactly(product.id, other_product.id)
    end

    it "rejects an edition that belongs to another product" do
      other_product = workspace.products.create!(name: "Other", price: 50)
      foreign_edition = other_product.editions.create!(name: "Foreign", starts_on: Date.current + 30.days)

      expect {
        submit(reserva_params("edition_id" => foreign_edition.id.to_s))
      }.to raise_error(ActiveRecord::RecordInvalid, /edition id is invalid/)
    end

    it "rejects a started edition" do
      started = product.editions.create!(name: "Started", starts_on: Date.current - 1.day, ends_on: Date.current + 30.days)

      expect {
        submit(reserva_params("edition_id" => started.id.to_s))
      }.to raise_error(ActiveRecord::RecordInvalid, /edition id is invalid/)
    end

    it "rejects an edition without dates" do
      undated = product.editions.create!(name: "No dates")

      expect {
        submit(reserva_params("edition_id" => undated.id.to_s))
      }.to raise_error(ActiveRecord::RecordInvalid, /edition id is invalid/)
    end
  end

  describe "subscription opt-in on deal forms" do
    let!(:publication) { create_beehiiv_publication!(workspace) }

    before do
      ActiveJob::Base.queue_adapter = :test
      allow(CreamFeatures).to receive(:enabled?).and_call_original
      allow(CreamFeatures).to receive(:enabled?).with(:marketing_consent).and_return(true)
      SubscriptionType.ensure_defaults!(workspace)
    end

    it "creates person and subscription and enqueues Beehiiv push when newsletter is checked" do
      params = contacto_lead_params("newsletter_opt_in" => "1")

      expect {
        result = submit(params)
        expect(result.person.email).to eq("lead@example.com")
        expect(result.deal).to be_present
      }.to change(Person, :count).by(1)
        .and change(EmailSubscription, :count).by(1)
        .and have_enqueued_job(BeehiivPushJob).with(publication.id, kind_of(Integer), "subscribe", {"reactivate" => false})

      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      person = Person.find_by!(email: "lead@example.com")
      expect(EmailSubscription.find_by!(person: person, subscription_type: newsletter).status).to eq("subscribed")
    end

    it "reuses existing person and still creates subscription when newsletter is checked" do
      company = create_company!(workspace, name: "Acme SL")
      existing = create_person!(workspace, company: company, email: "lead@example.com", first_name: "Existente")

      params = contacto_lead_params("newsletter_opt_in" => "1")

      expect {
        submit(params)
      }.to change(Person, :count).by(0)
        .and change(EmailSubscription, :count).by(1)
        .and have_enqueued_job(BeehiivPushJob)

      newsletter = workspace.subscription_types.find_by!(slug: "newsletter")
      expect(EmailSubscription.find_by!(person: existing, subscription_type: newsletter).status).to eq("subscribed")
    end
  end

  describe "corporate email requirement" do
    before { lead_form.update!(require_corporate_email: true) }

    it "rejects free email domains when enabled" do
      expect {
        submit(contacto_lead_params("email" => "ana@gmail.com"))
      }.to raise_error(ActiveRecord::RecordInvalid, /email corporativo/)
        .and change(Person, :count).by(0)
        .and change(Deal, :count).by(0)
    end

    it "accepts corporate domains when enabled" do
      expect {
        submit(contacto_lead_params("email" => "ana@entaina.com"))
      }.to change(Person, :count).by(1)
        .and change(Deal, :count).by(1)
    end

    it "accepts free email when disabled" do
      lead_form.update!(require_corporate_email: false)

      expect {
        submit(contacto_lead_params("email" => "ana@gmail.com"))
      }.to change(Person, :count).by(1)
    end
  end
end
