class LeadFormSubmissionProcessor
  Result = Data.define(:submission, :deal, :person)

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
      company = resolve_company!(person:, created:)
      person.update!(company: company) if person.company_id != company.id
      deal = create_deal!(person:, company:)
      submission = LeadSubmission.create!(
        workspace: workspace,
        lead_form: lead_form,
        deal: deal,
        person: person,
        data: submission_data,
        metadata: submission_metadata
      )
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
    lead_form.lead_submissions.where(created_at: 1.hour.ago..).count >= LeadForm::MAX_SUBMISSIONS_PER_FORM_PER_HOUR
  end

  def email_throttled?
    email = normalized_email
    return false if email.blank?

    person = workspace.people.with_email(email).first
    return false unless person

    LeadSubmission.where(person: person, created_at: 24.hours.ago..).count >= LeadForm::MAX_SUBMISSIONS_PER_EMAIL_PER_DAY
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
      phone: params["phone"].presence,
      job_title: params["job_title"].presence,
      company: LeadForm.placeholder_company_for(workspace),
      source: "web_form",
      owner: lead_form.responsible
    )
    [ person, true ]
  end

  def resolve_company!(person:, created:)
    return resolve_submitted_company! if lead_form.collects_company?
    return LeadForm.placeholder_company_for(workspace) if created

    person.company
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

  def create_deal!(person:, company:)
    pipeline = lead_form.resolve_pipeline(help_type: params["help_type"])
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
          title: "Contactar lead",
          due_on: Task.default_due_on,
          workspace: workspace,
          user: lead_form.responsible,
          assignee: lead_form.responsible
        )
      ]
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

  def validate_submission!
    person = Person.new
    person.errors.add(:first_name, "can't be blank") if params["first_name"].blank?
    person.errors.add(:email, "can't be blank") if normalized_email.blank?
    person.errors.add(:phone, "can't be blank") if params["phone"].blank?
    person.errors.add(:base, "company name is required") if lead_form.collects_company? && params["company_name"].blank?
    person.errors.add(:job_title, "can't be blank") if lead_form.requires_job_title? && params["job_title"].blank?

    if lead_form.contacto_template?
      person.errors.add(:base, "help type is required") if params["help_type"].blank?
    end

    if lead_form.liderando_ia_template? || lead_form.desarrollando_ia_template?
      person.errors.add(:base, "audience is required") if params["audience"].blank?
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
