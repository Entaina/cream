class BookingSubmissionProcessor
  Result = Data.define(:person, :deal)

  def self.call(booking_page:, event_type:, params:, request:)
    new(booking_page:, event_type:, params:, request:).call
  end

  def initialize(booking_page:, event_type:, params:, request:)
    @booking_page = booking_page
    @event_type = event_type
    @workspace = booking_page.workspace
    @params = params.to_h.stringify_keys
    @request = request
  end

  def call
    return Result.new(person: nil, deal: nil) if @booking_page.crm_none?

    ActiveRecord::Base.transaction do
      person, created = find_or_create_person!
      company = created ? LeadForm.placeholder_company_for(@workspace) : person.company
      person.update!(company:) if person.company_id != company.id
      deal = find_or_create_deal!(person:, company:) if @booking_page.crm_deal?
      Result.new(person:, deal:)
    end
  end

  private

  def find_or_create_person!
    email = @params["email"].to_s.strip.downcase
    existing = @workspace.people.with_email(email).first
    return [existing, false] if existing

    person = @workspace.people.create!(
      email: @params["email"].to_s.strip,
      first_name: @params["first_name"].to_s.strip,
      last_name: @params["last_name"].to_s.strip,
      phone: @params["phone"].presence,
      company: LeadForm.placeholder_company_for(@workspace),
      source: "booking",
      owner: @booking_page.host
    )
    [person, true]
  end

  def find_or_create_deal!(person:, company:)
    pipeline = @booking_page.pipeline
    stage = pipeline.first_stage

    if @booking_page.reuse_existing_deal?
      existing = person.deals
        .where(pipeline_id: pipeline.id, pipeline_stage_id: stage.id)
        .order(created_at: :desc)
        .first

      if existing
        existing.update!(company: company) if existing.company_id != company.id
        return existing
      end
    end

    create_deal!(person:, company:, pipeline:, stage:)
  end

  def create_deal!(person:, company:, pipeline: nil, stage: nil)
    pipeline ||= @booking_page.pipeline
    stage ||= pipeline.first_stage
    deal_name = [person.display_name, @event_type.localized_name, @booking_page.name].compact.join(" — ")
    @workspace.deals.create!(
      name: deal_name,
      company: company,
      pipeline: pipeline,
      pipeline_stage: stage,
      owner: @booking_page.host,
      contacts: [person],
      tasks: [
        Task.new(
          title: "Preparar reunión reservada",
          due_on: Task.default_due_on,
          workspace: @workspace,
          user: @booking_page.host,
          assignee: @booking_page.host
        )
      ]
    )
  end
end
