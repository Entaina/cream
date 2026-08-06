class LeadFormSubmissionProcessor
  Result = Data.define(:submission, :deal, :person)

  PERSON_FILLABLE_FIELDS = %w[first_name last_name phone job_title].freeze

  def self.call(lead_form:, params:, request:)
    new(lead_form:, params:, request:).call
  end

  def initialize(lead_form:, params:, request:)
    @lead_form = lead_form
    @workspace = lead_form.workspace
    @params = params.to_h.stringify_keys
    @request = request
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
      attach_deal_product!(deal)
      submission = persist_submission!(deal:, person:, deal_created:)
      enqueue_emails(submission:, deal:, person:)
      Result.new(submission:, deal:, person:)
    end
  end

  private

  attr_reader :lead_form, :workspace, :params, :request

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
    lead_form.collects_company? || lead_form.liderando_ia_template?
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
    deal_name = "#{deal_name} (#{lead_form.help_type_label(params['help_type'])})" if lead_form.contacto_template? && params["help_type"].present?
    deal_name = "#{deal_name} (Demo)" if lead_form.adoption_template?
    workspace.deals.create!(
      name: deal_name,
      company: company,
      pipeline: pipeline,
      pipeline_stage: stage,
      owner: lead_form.responsible,
      contacts: [ person ],
      tasks: [
        Task.new(
          title: lead_form.first_task_title,
          due_on: Date.current + lead_form.first_task_due_days.days,
          workspace: workspace,
          user: lead_form.responsible,
          assignee: lead_form.responsible
        )
      ]
    )
  end

  def attach_deal_product!(deal)
    product = resolved_product
    return unless product

    edition = resolved_edition(product)
    return if deal.deal_products.exists?(product_id: product.id, edition_id: edition&.id)

    deal.deal_products.create!(product: product, edition: edition, quantity: 1)
  end

  def resolved_product
    lead_form.resolved_product(product_id_param: params["product_id"])
  end

  def resolved_edition(product)
    edition_id = params["edition_id"].presence
    return if edition_id.blank?

    product.editions.not_finished.find_by(id: edition_id)
  end

  def persist_submission!(deal:, person:, deal_created:)
    now = Time.current.iso8601
    new_data = submission_data
    new_metadata = submission_metadata.merge(
      "last_submitted_at" => now,
      "submissions_at" => [ now ]
    )

    if deal_created
      return LeadSubmission.create!(
        workspace: workspace,
        lead_form: lead_form,
        deal: deal,
        person: person,
        data: new_data,
        metadata: new_metadata
      )
    end

    existing = deal.lead_submission
    if existing
      existing.update!(
        data: merge_submission_hashes(existing.data, new_data),
        metadata: merge_submission_hashes(existing.metadata, new_metadata).merge(
          "last_submitted_at" => now,
          "submissions_at" => Array(existing.metadata["submissions_at"]) + [ now ]
        )
      )
      return existing
    end

    LeadSubmission.create!(
      workspace: workspace,
      lead_form: lead_form,
      deal: deal,
      person: person,
      data: new_data,
      metadata: new_metadata
    )
  end

  def merge_submission_hashes(existing, incoming)
    merged = existing.stringify_keys.dup
    incoming.stringify_keys.each do |key, value|
      next if value.blank? && !value.is_a?(FalseClass)

      existing_value = merged[key]
      merged[key] = value if existing_value.blank? && !existing_value.is_a?(FalseClass)
    end
    merged
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
    return number unless lead_form.desarrollando_ia_reserva_template?

    prefix = params["phone_prefix"].presence || "+34"
    "#{prefix} #{number}"
  end

  def validate_submission!
    person = Person.new
    person.errors.add(:first_name, "can't be blank") if params["first_name"].blank?
    person.errors.add(:last_name, "can't be blank") if params["last_name"].blank?
    person.errors.add(:email, "can't be blank") if normalized_email.blank?
    person.errors.add(:phone, "can't be blank") if lead_form.require_phone? && resolved_phone.blank?
    person.errors.add(:base, "company name is required") if requires_company_name? && params["company_name"].blank?
    person.errors.add(:job_title, "can't be blank") if lead_form.requires_job_title? && params["job_title"].blank?
    person.errors.add(:email, "is invalid") if normalized_email.present? && !normalized_email.match?(URI::MailTo::EMAIL_REGEXP)

    if lead_form.contacto_template?
      person.errors.add(:base, "help type is required") if params["help_type"].blank?
    end

    if lead_form.liderando_ia_template? || lead_form.desarrollando_ia_template?
      person.errors.add(:base, "audience is required") if params["audience"].blank?
    end

    if lead_form.reserva_template?
      person.errors.add(:base, "edition is required") if params["edition_id"].blank?

      product = resolved_product
      if product.nil?
        person.errors.add(:base, "product is required")
      elsif params["edition_id"].present? && resolved_edition(product).nil?
        person.errors.add(:base, "edition is invalid")
      end
    end

    if lead_form.desarrollando_ia_template?
      person.errors.add(:base, "tech profile is required") if params["tech_profile"].blank?
    end

    if lead_form.indice_adopcion_ia_template?
      person.errors.add(:base, "employee range is required") if params["employee_range"].blank?
    end

    raise ActiveRecord::RecordInvalid.new(person) if person.errors.any?
  end

  def enqueue_emails(submission:, deal:, person:)
    template = lead_form.email_template
    rendered_body = template.render_for(person)
    rendered_subject = render_template_subject(template, person)

    message = workspace.email_messages.create!(
      user: lead_form.responsible,
      record: deal,
      to_address: person.email,
      subject: rendered_subject,
      body: rendered_body
    )
    SendViaGmailJob.perform_later(message.id)

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

  def render_template_subject(template, person)
    template.subject.to_s.gsub(/\{(\w+)\}/) do
      token = Regexp.last_match(1)
      case token
      when "first_name" then person.first_name
      when "last_name" then person.last_name
      when "name" then person.display_name
      when "company" then person.company&.name
      when "email" then person.email
      else "{#{token}}"
      end.to_s
    end
  end
end
