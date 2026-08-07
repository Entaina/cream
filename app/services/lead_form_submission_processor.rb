class LeadFormSubmissionProcessor
  Result = Data.define(:submission, :deal, :person)

  PERSON_FILLABLE_FIELDS = %w[first_name last_name phone job_title].freeze

  def self.call(lead_form:, params:, request:, product: nil, open_editions: nil)
    new(lead_form:, params:, request:, product:, open_editions:).call
  end

  def initialize(lead_form:, params:, request:, product: nil, open_editions: nil)
    @lead_form = lead_form
    @workspace = lead_form.workspace
    @params = params.to_h.stringify_keys
    @request = request
    @product = product || lead_form.resolved_product(product_id_param: @params["product_id"])
    @open_editions = open_editions.nil? ? lead_form.open_editions_for(@product) : open_editions
  end

  # Returns nil (silent discard) when containment caps are exceeded.
  def call
    return nil if throttled?

    ActiveRecord::Base.transaction do
      person, created = find_or_create_person!
      fill_person_blanks!(person) unless created
      company = resolve_company!(person:, created:)
      fill_company_blanks!(company)
      person.update!(company: company) if person.company_id != company.id
      deal, deal_created = find_or_create_deal!(person:, company:)
      create_first_task!(deal) unless deal_created
      attach_deal_product!(deal)
      submission = persist_submission!(deal:, person:)
      enqueue_emails(submission:, deal:, person:)
      Result.new(submission:, deal:, person:)
    end
  end

  private

  attr_reader :lead_form, :workspace, :params, :request, :product, :open_editions

  def throttled?
    form_throttled? || email_throttled?
  end

  def form_throttled?
    cutoff = 1.hour.ago
    submissions = LeadSubmission.where(lead_form: lead_form).to_a
    submission_times_in_window(submissions, cutoff).count >= LeadForm::MAX_SUBMISSIONS_PER_FORM_PER_HOUR
  end

  def email_throttled?
    email = normalized_email
    return false if email.blank?

    person = workspace.people.with_email(email).first
    return false unless person

    cutoff = 24.hours.ago
    submission_times_in_window(LeadSubmission.where(person: person).to_a, cutoff).count >= LeadForm::MAX_SUBMISSIONS_PER_EMAIL_PER_DAY
  end

  def submission_times_in_window(submissions, cutoff)
    submissions.flat_map { |submission| submission_effective_times(submission) }.select { |time| time >= cutoff }
  end

  def submission_effective_times(submission)
    tracked = Array(submission.metadata["submissions_at"]).filter_map do |timestamp|
      Time.zone.parse(timestamp)
    rescue ArgumentError, TypeError
      nil
    end
    return tracked if tracked.any?

    [ submission.created_at ]
  end

  def find_or_create_person!
    validate_submission!

    email = normalized_email

    existing = workspace.people.with_email(email).first
    return [ existing, false ] if existing

    person = workspace.people.create!(
      email: params["email"].to_s.strip,
      first_name: params["first_name"].to_s,
      last_name: params["last_name"].to_s,
      phone: resolved_phone,
      job_title: params["job_title"].presence,
      company: LeadForm.placeholder_company_for(workspace),
      source: "web_form",
      owner: lead_form.responsible
    )
    [ person, true ]
  end

  def fill_person_blanks!(person)
    updates = PERSON_FILLABLE_FIELDS.each_with_object({}) do |field, attrs|
      next if person.public_send(field).present?

      value = person_field_value(field)
      attrs[field] = value if value.present?
    end
    person.update!(updates) if updates.any?
  end

  def resolve_company!(person:, created:)
    return resolve_submitted_company! if requires_company_name?
    return LeadForm.placeholder_company_for(workspace) if created

    person.company
  end

  def requires_company_name?
    lead_form.collects_company?
  end

  def fill_company_blanks!(company)
    updates = {}
    if company.fiscal_information.blank? && params["company_cif"].present?
      updates[:fiscal_information] = params["company_cif"].to_s.strip
    end
    if company.employee_range.blank?
      range = params["employee_range"].to_s.strip
      updates[:employee_range] = range if range.present? && Company::EMPLOYEE_RANGES.include?(range)
    end
    company.update!(updates) if updates.any?
  end

  def resolve_submitted_company!
    find_company_by_cif || find_company_by_name || create_company!
  end

  def find_company_by_cif
    cif = params["company_cif"].to_s.strip
    return if cif.blank?

    workspace.companies.where("fiscal_information ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(cif)}%").first
  end

  def find_company_by_name
    name = params["company_name"].to_s.strip
    return if name.blank?

    workspace.companies.where("LOWER(TRIM(name)) = ?", name.downcase).first
  end

  def create_company!
    name = params["company_name"].to_s.strip.presence || "Empresa sin nombre"
    fiscal_information = params["company_cif"].to_s.strip.presence
    employee_range = params["employee_range"].to_s.strip.presence
    attrs = { name:, fiscal_information:, owner: lead_form.responsible }
    attrs[:employee_range] = employee_range if employee_range.present? && Company::EMPLOYEE_RANGES.include?(employee_range)
    workspace.companies.create!(attrs)
  end

  def find_or_create_deal!(person:, company:)
    pipeline = lead_form.resolve_pipeline(help_type: params["help_type"])
    existing = person.deals.open_deals.where(pipeline_id: pipeline.id).order(created_at: :desc).first

    if existing
      existing.update!(company: company) if existing.company_id != company.id
      advance_stage!(existing, pipeline)
      return [ existing, false ]
    end

    [ create_deal!(person:, company:, pipeline:), true ]
  end

  def advance_stage!(deal, pipeline)
    target = lead_form.configured_stage_for(pipeline)
    return if target.nil? || deal.pipeline_stage_id == target.id
    return if deal.pipeline_stage.position >= target.position

    deal.move_to_stage!(target)
  rescue ActiveRecord::RecordInvalid
    deal.reload
  end

  def create_deal!(person:, company:, pipeline: nil)
    pipeline ||= lead_form.resolve_pipeline(help_type: params["help_type"])
    stage = lead_form.resolve_stage(for_pipeline: pipeline)
    deal_name = [ person.display_name, lead_form.name ].compact.join(" — ")
    deal_name = "#{deal_name} (#{lead_form.help_type_label(params['help_type'])})" if params["help_type"].present?
    deal = workspace.deals.create!(
      name: deal_name,
      company: company,
      pipeline: pipeline,
      pipeline_stage: stage,
      owner: lead_form.responsible,
      contacts: [ person ],
      tasks: [ Task.new(first_task_attributes) ]
    )
    deal
  end

  def create_first_task!(deal)
    deal.tasks.create!(first_task_attributes)
  end

  def first_task_attributes
    {
      title: lead_form.first_task_title,
      due_on: Date.current + lead_form.first_task_due_days.days,
      workspace: workspace,
      user: lead_form.responsible,
      assignee: lead_form.responsible
    }
  end

  def attach_deal_product!(deal)
    product = resolved_product
    return unless product

    edition = resolved_edition(product)
    existing = deal.deal_products.find_by(product_id: product.id)
    if existing
      existing.update!(edition: edition) if existing.edition_id != edition&.id
      return
    end

    deal.deal_products.create!(product: product, edition: edition, quantity: 1)
  end

  def resolved_product
    lead_form.resolved_product(product_id_param: params["product_id"])
  end

  def resolved_edition(product)
    edition_id = params["edition_id"].presence
    return if edition_id.blank?

    product.editions.not_started.find_by(id: edition_id)
  end

  def persist_submission!(deal:, person:)
    now = Time.current.iso8601

    LeadSubmission.create!(
      workspace: workspace,
      lead_form: lead_form,
      deal: deal,
      person: person,
      data: submission_data,
      metadata: submission_metadata.merge(
        "last_submitted_at" => now,
        "submissions_at" => [ now ]
      )
    )
  end

  def submission_data
    excluded = LeadForm::METADATA_FIELDS + [ LeadForm::HONEYPOT_FIELD, LeadForm::TIMESTAMP_FIELD, "gdpr_consent" ]
    data = params.except(*excluded).reject { |_key, value| value.blank? }
    data["newsletter_opt_in"] = params["newsletter_opt_in"] == "1"
    data
  end

  def submission_metadata
    LeadForm::METADATA_FIELDS.index_with { |key| metadata_value(key) }.compact.merge(
      "user_agent" => request.user_agent,
      "ip" => request.remote_ip
    )
  end

  def metadata_value(key)
    case key
    when "lead_form_slug" then lead_form.slug
    when "lead_form_name" then lead_form.name
    else params[key].presence
    end
  end

  def normalized_email
    params["email"].to_s.strip.downcase.presence
  end

  def person_field_value(field)
    return resolved_phone if field == "phone"

    params[field].presence
  end

  def resolved_phone
    number = params["phone"].to_s.strip
    return if number.blank?

    prefix = params["phone_prefix"].presence
    return "#{prefix} #{number}" if prefix.present?

    number
  end

  def validate_submission!
    submission_schema.validate!(params)
  end

  def submission_schema
    @submission_schema ||= LeadFormTemplates::SubmissionSchema.build(
      lead_form: lead_form,
      product: product,
      open_editions: open_editions,
      params: params
    )
  end

  def enqueue_emails(submission:, deal:, person:)
    if lead_form.email_template
      template = lead_form.email_template
      extra_tokens = lead_email_tokens(submission:)
      rendered_body = template.render_for(person, extra_tokens:)
      rendered_subject = template.render_subject_for(person, extra_tokens:)

      message = workspace.email_messages.create!(
        user: lead_form.responsible,
        record: deal,
        to_address: person.email,
        subject: rendered_subject,
        body: rendered_body
      )
      attach_template_files(message, template)
      SendViaGmailJob.perform_later(message.id)
    end

    if CreamFeatures.enabled?(:notifications)
      NotificationService.notify_lead_submission(
        responsible: lead_form.responsible,
        lead_form: lead_form,
        deal: deal,
        person: person
      )
    end

    LeadFormMailer.responsible_notification(
      responsible: lead_form.responsible,
      lead_form: lead_form,
      submission: submission,
      deal: deal
    ).deliver_later
  end

  def attach_template_files(message, template)
    return unless template.attachments.attached?

    template.attachments.each { |file| message.attachments.attach(file.blob) }
  end

  def lead_email_tokens(submission:)
    tokens = {
      "form_name" => lead_form.name,
      "form_slug" => lead_form.slug,
      "product" => resolved_product&.name.to_s,
      "edition" => resolved_edition_for_email(submission)&.display_name.to_s
    }

    submission_schema.fields.each do |field|
      tokens[field.name] = stringify_field_token(field.name)
    end

    tokens
  end

  def stringify_field_token(name)
    value = case name
    when "newsletter_opt_in"
      params.key?("newsletter_opt_in") ? params["newsletter_opt_in"] == "1" : nil
    else
      params[name]
    end

    stringify_token_value(value)
  end

  def resolved_edition_for_email(submission)
    edition_id = submission.data["edition_id"].presence || params["edition_id"].presence
    return if edition_id.blank?

    product = resolved_product
    return unless product

    product.editions.find_by(id: edition_id)
  end

  def stringify_token_value(value)
    case value
    when Array
      value.map(&:to_s).join(", ")
    when TrueClass, FalseClass
      value.to_s
    when nil
      ""
    else
      value.to_s
    end
  end
end
