# Links Gmail threads to CRM deals by importing EmailMessage rows from an add-on payload.
class GmailThreadLinker
  class CompanyRequired < StandardError
    attr_reader :name, :domain

    def initialize(name: nil, domain: nil)
      @name = name
      @domain = domain
      super("Company doesn't exist")
    end
  end

  class ContactOutsideCompany < StandardError
    attr_reader :email, :company_name

    def initialize(email:, company_name:)
      @email = email
      @company_name = company_name
      super("Contact #{email} belongs to another company (#{company_name})")
    end
  end

  DEAL_INCLUDES = [
    :company, :pipeline, :pipeline_stage, :owner, :contacts, :tasks,
    {deal_products: [:product, :edition]}
  ].freeze
  FREE_EMAIL_DOMAINS = %w[
    gmail.com googlemail.com hotmail.com outlook.com live.com yahoo.com yahoo.es
    icloud.com me.com proton.me protonmail.com aol.com
  ].freeze

  EmailAddressParser = Class.new do
    def self.extract(raw)
      return nil if raw.blank?

      match = raw.to_s.match(/<([^>]+)>/)
      email = (match ? match[1] : raw).strip.downcase
      email.match?(URI::MailTo::EMAIL_REGEXP) ? email : nil
    end

    def self.extract_all(raw)
      return [] if raw.blank?

      raw.to_s.split(/[,;]/).filter_map { |part| extract(part) }.uniq
    end
  end

  def initialize(workspace:, user:)
    @workspace = workspace
    @user = user
  end

  def status(gmail_thread_id:, rfc822_message_ids: [], participant_emails: [])
    linked_deals = linked_deals_for(gmail_thread_id: gmail_thread_id, rfc822_message_ids: rfc822_message_ids)
    suggestions = suggested_deals_for(participant_emails: participant_emails) - linked_deals

    {
      linked: linked_deals.map { |deal| deal_payload(deal) },
      suggestions: suggestions.first(5).map { |deal| deal_payload(deal) },
      suggested_companies: suggested_companies_for(participant_emails: participant_emails)
    }
  end

  def link(thread:, deal_id: nil, new_deal: nil)
    result = nil
    ActiveRecord::Base.transaction do
      deal = reload_deal!(resolve_deal(deal_id: deal_id, new_deal: new_deal, thread: thread))
      imported = import_messages!(deal: deal, thread: thread)
      deal.track_activity(
        "email_linked",
        user: @user,
        metadata: {
          gmail_thread_id: thread[:gmail_thread_id],
          messages_imported: imported.size,
          subject: thread.dig(:messages, 0, :subject)
        }
      )
      result = {
        deal: deal_payload(deal),
        imported_count: imported.size,
        messages: imported.map { |message| message_payload(message) }
      }
    end
    result
  end

  def add_contacts!(deal:, contacts:)
    entries = normalize_contact_entries(contacts)
    deal = reload_deal!(deal)
    company = deal.company

    ActiveRecord::Base.transaction do
      new_ids = entries.filter_map do |entry|
        email = entry[:email]
        next if owned_email?(email)

        person = resolve_person_for_deal_company!(
          email,
          company: company,
          partner_id: deal.partner_id,
          name: entry[:name]
        )
        person.id unless deal.contact_ids.include?(person.id)
      end

      deal.contact_ids = (deal.contact_ids + new_ids).uniq
      deal.save!
    end

    deal_payload(reload_deal!(deal))
  end

  private

  def linked_deals_for(gmail_thread_id:, rfc822_message_ids:)
    workspaces = @user.workspaces.to_a
    workspace_ids = workspaces.map(&:id)
    scope = EmailMessage.where(workspace_id: workspace_ids, record_type: "Deal")
    deal_ids = []

    if gmail_thread_id.present?
      deal_ids += scope.where(gmail_thread_id: gmail_thread_id).distinct.pluck(:record_id)
    end

    message_ids = Array(rfc822_message_ids).filter_map(&:presence).uniq
    if message_ids.any?
      deal_ids += scope.where(rfc822_message_id: message_ids).distinct.pluck(:record_id)
    end

    deal_ids = deal_ids.uniq
    return [] if deal_ids.empty?

    workspaces.flat_map do |workspace|
      visible_deals(workspace).where(id: deal_ids).includes(DEAL_INCLUDES).to_a
    end
  end

  # Deals the user may see in `workspace`, according to DealPolicy::Scope.
  def visible_deals(workspace = @workspace)
    Pundit.policy_scope(UserContext.new(user: @user, workspace: workspace), workspace.deals)
  end

  def suggested_deals_for(participant_emails:)
    emails = participant_emails
      .filter_map { |raw| EmailAddressParser.extract(raw) }
      .reject { |email| owned_email?(email) }
      .uniq
    return [] if emails.empty?

    person_ids = emails.flat_map { |email| @workspace.people.with_email(email).pluck(:id) }.uniq
    return [] if person_ids.empty?

    visible_deals.joins(:deal_contacts)
      .where(deal_contacts: {person_id: person_ids})
      .includes(DEAL_INCLUDES)
      .distinct
      .order(updated_at: :desc)
      .limit(5)
      .to_a
  end

  def resolve_deal(deal_id:, new_deal:, thread:)
    return find_deal!(deal_id) if deal_id.present?

    attrs = (new_deal || {}).symbolize_keys
    name = attrs[:name].presence || thread.dig(:messages, 0, :subject).presence || "Deal from email"
    pipeline_stage = resolve_pipeline_stage(attrs[:pipeline_stage_id])
    external_email = first_external_email(thread)
    company = resolve_company!(external_email, attrs)
    people = people_for_new_deal(attrs, thread: thread, company: company, external_email: external_email)

    deal = @workspace.deals.new(
      name: name,
      company: company,
      pipeline: pipeline_stage.pipeline,
      pipeline_stage: pipeline_stage,
      owner: @user,
      contacts: people,
      tasks: [
        Task.new(
          title: "Next action",
          due_on: Date.current + 3,
          workspace: @workspace,
          user: @user,
          assignee: @user
        )
      ]
    )
    deal.save!
    deal
  end

  def find_deal!(deal_id)
    visible_deals.find(deal_id)
  end

  def resolve_pipeline_stage(stage_id)
    return @workspace.pipeline_stages.find(stage_id) if stage_id.present?

    pipeline = Pipeline.default_for(@workspace) || Pipeline.create_default!(@workspace)
    pipeline.first_stage
  end

  def first_external_email(thread)
    thread_participant_emails(thread).find { |email| !owned_email?(email) }
  end

  def thread_participant_emails(thread)
    Array(thread[:messages]).flat_map do |message|
      EmailAddressParser.extract_all(message[:from]) +
        EmailAddressParser.extract_all(message[:to]) +
        EmailAddressParser.extract_all(message[:cc])
    end.uniq
  end

  def people_for_new_deal(attrs, thread:, company:, external_email:)
    entries = build_new_deal_contact_entries(attrs, thread: thread)
    people = entries.filter_map do |entry|
      next if owned_email?(entry[:email])

      resolve_person_for_deal_company!(
        entry[:email],
        company: company,
        partner_id: nil,
        name: entry[:name]
      )
    end.uniq

    return people if people.any?

    [find_or_create_person(external_email, company: company)]
  end

  def build_new_deal_contact_entries(attrs, thread:)
    emails = Array(attrs[:contact_emails]).filter_map { |raw| normalize_email(raw) }.uniq
    emails.reject! { |email| owned_email?(email) }

    primary = first_external_email(thread)
    emails << primary if primary.present? && !emails.include?(primary)

    named_email = normalize_email(attrs[:named_contact_email])
    contact_name = attrs[:contact_name].to_s.strip.presence

    emails.uniq.map do |email|
      {email: email, name: ((named_email.present? && email == named_email) ? contact_name : nil)}
    end
  end

  def normalize_contact_entries(contacts)
    Array(contacts).filter_map do |entry|
      hash = entry.symbolize_keys
      email = normalize_email(hash[:email])
      next if email.blank?

      name = hash[:name].to_s.strip.presence
      {email: email, name: name}
    end.uniq { |entry| entry[:email] }
  end

  def normalize_email(raw)
    return nil if raw.blank?

    EmailAddressParser.extract(raw) || raw.to_s.strip.downcase.presence
  end

  def resolve_person_for_deal_company!(email, company:, partner_id:, name: nil)
    email = normalize_email(email)
    raise ArgumentError, "Invalid email" if email.blank?

    person = @workspace.people.with_email(email).first
    if person
      allowed = [company.id, partner_id].compact
      unless allowed.include?(person.company_id)
        raise ContactOutsideCompany.new(email: email, company_name: person.company.name)
      end
      return person
    end

    find_or_create_person(email, company: company, name: name)
  end

  def suggested_companies_for(participant_emails:)
    domains = external_domains(participant_emails)
    return [] if domains.empty?

    matches = domains.flat_map { |domain| companies_like_domain(domain) }
    matches.uniq.first(5).map { |company| company_suggestion(company) }
  end

  def resolve_company!(external_email, attrs)
    domain = storable_domain(external_email)
    if attrs[:company_id].present?
      company = @workspace.companies.find(attrs[:company_id])
      assign_domain_if_blank!(company, domain)
      return company
    end

    named = attrs[:company_name].to_s.strip
    if named.present?
      existing = @workspace.companies.where("LOWER(companies.name) = ?", named.downcase).first
      if existing
        assign_domain_if_blank!(existing, domain)
        return existing
      end

      raise CompanyRequired.new(name: named, domain: domain) unless confirmed_create?(attrs[:create_company])

      return @workspace.companies.create!(name: named, domain: domain)
    end

    if domain.present?
      existing = @workspace.companies.where(
        "LOWER(REGEXP_REPLACE(companies.domain, '\\Awww\\.', '')) = ?",
        domain
      ).first
      return existing if existing
    end

    raise CompanyRequired.new(name: company_name_from_domain(domain), domain: domain) unless confirmed_create?(attrs[:create_company])

    @workspace.companies.create!(name: company_name_from_domain(domain), domain: domain)
  end

  def external_domains(raw_emails)
    Array(raw_emails).filter_map { |raw| EmailAddressParser.extract(raw) }
      .reject { |email| owned_email?(email) }
      .filter_map { |email| storable_domain(email) }
      .uniq
  end

  def companies_like_domain(domain)
    normalized = CompanyNameNormalizer.normalize_domain(domain)
    label = normalized.split(".").first.to_s
    exact = @workspace.companies.where(
      "LOWER(REGEXP_REPLACE(companies.domain, '\\Awww\\.', '')) = ?",
      normalized
    )
    return exact.to_a if label.length < 3

    like = "%#{Company.sanitize_sql_like(label)}%"
    similar = @workspace.companies.where(
      "companies.name ILIKE :q OR companies.domain ILIKE :q",
      q: like
    ).limit(5)
    (exact.to_a + similar.to_a).uniq
  end

  def company_suggestion(company)
    {id: company.id, name: company.name, domain: company.domain}
  end

  def storable_domain(email_or_domain)
    raw = email_or_domain.to_s.strip.downcase
    return nil if raw.blank?

    domain = raw.include?("@") ? raw.split("@").last : raw
    return nil if domain.blank? || free_email_domain?(domain)

    domain
  end

  def free_email_domain?(domain)
    FREE_EMAIL_DOMAINS.include?(domain.to_s.downcase)
  end

  def company_name_from_domain(domain)
    domain.present? ? domain.split(".").first.to_s.capitalize : "Unknown company"
  end

  def confirmed_create?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def assign_domain_if_blank!(company, domain)
    return company if domain.blank? || company.domain.present?

    company.update!(domain: domain)
    company
  end

  def find_or_create_person(external_email, company:, name: nil)
    return create_placeholder_person(company) if external_email.blank?

    person = @workspace.people.with_email(external_email).first
    return person if person

    first_name, last_name = names_from_contact(name, external_email)
    @workspace.people.create!(
      company: company,
      email: external_email,
      first_name: first_name,
      last_name: last_name,
      owner: @user
    )
  end

  def names_from_contact(name, email)
    if name.present?
      parts = name.strip.split(/\s+/, 2)
      return [parts[0], parts[1].to_s]
    end

    local_part = email.split("@").first
    first, last = local_part.split(/[._-]/, 2)
    [first.to_s.capitalize.presence || "Contact", last.to_s.capitalize]
  end

  def create_placeholder_person(company)
    @workspace.people.create!(
      company: company,
      first_name: "Contact",
      owner: @user
    )
  end

  def import_messages!(deal:, thread:)
    imported = []
    Array(thread[:messages]).each do |message_attrs|
      attrs = message_attrs.symbolize_keys
      next if duplicate_message?(deal: deal, attrs: attrs)

      direction = infer_direction(attrs[:from])
      imported << @workspace.email_messages.create!(
        user: @user,
        record: deal,
        direction: direction,
        status: (direction == "outbound") ? "sent" : "received",
        from_address: EmailAddressParser.extract(attrs[:from]) || attrs[:from].to_s,
        to_address: first_recipient(attrs[:to]) || "unknown@example.com",
        subject: attrs[:subject].presence || "(no subject)",
        body: message_body(attrs[:body]),
        gmail_message_id: attrs[:gmail_message_id],
        gmail_thread_id: thread[:gmail_thread_id],
        rfc822_message_id: attrs[:rfc822_message_id],
        created_at: parse_sent_at(attrs[:sent_at])
      )
    end
    imported
  end

  def duplicate_message?(deal:, attrs:)
    scope = @workspace.email_messages.where(record: deal)
    if attrs[:rfc822_message_id].present?
      return true if scope.exists?(rfc822_message_id: attrs[:rfc822_message_id])
    end
    if attrs[:gmail_message_id].present?
      return true if scope.exists?(gmail_message_id: attrs[:gmail_message_id])
    end

    false
  end

  def infer_direction(from_raw)
    from_email = EmailAddressParser.extract(from_raw)
    owned_email?(from_email) ? "outbound" : "inbound"
  end

  def owned_email?(email)
    return false if email.blank?

    email = email.downcase
    return true if @user.email_address.downcase == email

    connection = @workspace.gmail_connections.find_by(user_id: @user.id)
    connection&.email&.downcase == email
  end

  def message_body(raw)
    text = raw.to_s.gsub(/[\u00A0\u200B\u200C\u200D\uFEFF]/, " ").gsub(/\r\n?/, "\n").strip
    text.presence || "(no body)"
  end

  def first_recipient(to_raw)
    EmailAddressParser.extract_all(to_raw).first
  end

  def parse_sent_at(value)
    return Time.current if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    Time.current
  end

  def reload_deal!(deal)
    visible_deals.includes(DEAL_INCLUDES).find(deal.id)
  end

  def deal_payload(deal)
    pending_tasks = pending_tasks_for_addon(deal)
    task = pending_tasks.first
    {
      id: deal.id,
      workspace_id: deal.workspace_id,
      name: deal.name,
      stage: deal.stage_label,
      pipeline: deal.pipeline&.name,
      pipeline_id: deal.pipeline_id,
      pipeline_stage_id: deal.pipeline_stage_id,
      company_id: deal.company_id,
      company_name: deal.company&.name,
      value: deal.value.to_f,
      currency: deal.currency,
      owner_name: deal.owner&.name,
      contacts: deal.contacts.map(&:display_name),
      contact_emails: deal.contacts.filter_map { |person| person.email.presence&.downcase },
      expected_close_date: deal.expected_close_date&.iso8601,
      next_task: task ? task_summary(task) : nil,
      tasks: pending_tasks.map { |t| task_summary(t) },
      products: deal.deal_products.map { |line| product_line_label(line) },
      url: deal_url(deal)
    }
  end

  def pending_tasks_for_addon(deal)
    pending = deal.tasks.select { |t| t.completed_at.nil? }
    pending.sort_by { |t| [t.due_on ? 0 : 1, t.due_on || Date.new(9999, 12, 31), t.id] }.first(10)
  end

  def task_summary(task)
    {
      id: task.id,
      title: task.title,
      due_on: task.due_on&.iso8601,
      completed: task.completed?
    }
  end

  def product_line_label(line)
    label = line.product.name
    edition = line.edition&.name
    edition.present? ? "#{label} — #{edition}" : label
  end

  def message_payload(message)
    {
      id: message.id,
      direction: message.direction,
      subject: message.subject,
      from: message.from_address,
      to: message.to_address
    }
  end

  def deal_url(deal)
    base = ENV["CREAM_APP_URL"].presence
    return nil unless base

    "#{base.chomp("/")}/deals/#{deal.id}"
  end
end
