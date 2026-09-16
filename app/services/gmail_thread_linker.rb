# Links Gmail threads to CRM deals by importing EmailMessage rows from an add-on payload.
class GmailThreadLinker
  DEAL_INCLUDES = [
    :company, :pipeline, :pipeline_stage, :owner, :contacts, :tasks,
    {deal_products: [:product, :edition]}
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
      suggestions: suggestions.first(5).map { |deal| deal_payload(deal) }
    }
  end

  def link(thread:, deal_id: nil, new_deal: nil)
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

    {
      deal: deal_payload(deal),
      imported_count: imported.size,
      messages: imported.map { |message| message_payload(message) }
    }
  end

  private

  def linked_deals_for(gmail_thread_id:, rfc822_message_ids:)
    workspace_ids = @user.workspaces.pluck(:id)
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

    Deal.where(id: deal_ids, workspace_id: workspace_ids).includes(DEAL_INCLUDES).to_a
  end

  def suggested_deals_for(participant_emails:)
    emails = participant_emails
      .filter_map { |raw| EmailAddressParser.extract(raw) }
      .reject { |email| owned_email?(email) }
      .uniq
    return [] if emails.empty?

    person_ids = emails.flat_map { |email| @workspace.people.with_email(email).pluck(:id) }.uniq
    return [] if person_ids.empty?

    @workspace.deals.joins(:deal_contacts)
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
    company = find_or_create_company(external_email)
    person = find_or_create_person(external_email, company: company)

    deal = @workspace.deals.new(
      name: name,
      company: company,
      pipeline: pipeline_stage.pipeline,
      pipeline_stage: pipeline_stage,
      owner: @user,
      contacts: [person],
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
    @workspace.deals.find(deal_id)
  end

  def resolve_pipeline_stage(stage_id)
    return @workspace.pipeline_stages.find(stage_id) if stage_id.present?

    pipeline = Pipeline.default_for(@workspace) || Pipeline.create_default!(@workspace)
    pipeline.first_stage
  end

  def first_external_email(thread)
    participant_emails = Array(thread[:messages]).flat_map do |message|
      EmailAddressParser.extract_all(message[:from]) +
        EmailAddressParser.extract_all(message[:to])
    end.uniq
    participant_emails.find { |email| !owned_email?(email) }
  end

  def find_or_create_company(external_email)
    domain = external_email&.split("@")&.last
    if domain.present?
      company = @workspace.companies.find_by(domain: domain)
      return company if company
    end

    name = domain.present? ? domain.split(".").first.to_s.capitalize : "Unknown company"
    @workspace.companies.create!(name: name, domain: domain)
  end

  def find_or_create_person(external_email, company:)
    return create_placeholder_person(company) if external_email.blank?

    person = @workspace.people.with_email(external_email).first
    return person if person

    local_part = external_email.split("@").first
    first_name, last_name = local_part.split(/[._-]/, 2)
    @workspace.people.create!(
      company: company,
      email: external_email,
      first_name: first_name.to_s.capitalize.presence || "Contact",
      last_name: last_name.to_s.capitalize,
      owner: @user
    )
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
        body: attrs[:body].presence || "",
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
    @workspace.deals.includes(DEAL_INCLUDES).find(deal.id)
  end

  def deal_payload(deal)
    task = deal.next_pending_task
    {
      id: deal.id,
      workspace_id: deal.workspace_id,
      name: deal.name,
      stage: deal.stage_label,
      pipeline: deal.pipeline&.name,
      company_id: deal.company_id,
      company_name: deal.company&.name,
      value: deal.value.to_f,
      currency: deal.currency,
      owner_name: deal.owner&.name,
      contacts: deal.contacts.map(&:display_name),
      expected_close_date: deal.expected_close_date&.iso8601,
      next_task: task ? {title: task.title, due_on: task.due_on&.iso8601} : nil,
      products: deal.deal_products.map { |line| product_line_label(line) },
      url: deal_url(deal)
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
