require "csv"

class CsvImporter
  Result = Data.define(:created, :errors)

  IMPORTERS = {
    "Person" => :import_people,
    "Company" => :import_companies,
    "Deal" => :import_deals
  }.freeze

  def self.import(record_type, workspace:, user:, io:)
    new(workspace: workspace, user: user).public_send(IMPORTERS.fetch(record_type), io)
  end

  def initialize(workspace:, user:)
    @workspace = workspace
    @user = user
    @created = 0
    @errors = []
  end

  def import_people(io)
    each_row(io) do |row, line|
      company = find_or_create_company(row["company"])
      person = @workspace.people.new(
        first_name: row["first_name"],
        last_name: row["last_name"],
        email: row["email"],
        phone: row["phone"],
        job_title: row["job_title"],
        location: row["location"],
        company: company,
        owner: @user
      )
      save_record(person, line)
    end
    result
  end

  def import_companies(io)
    each_row(io) do |row, line|
      company = @workspace.companies.new(
        name: row["name"],
        domain: row["domain"],
        industry: row["industry"],
        employee_range: row["employee_range"],
        location: row["location"],
        annual_revenue: row["annual_revenue"],
        owner: @user
      )
      save_record(company, line)
    end
    result
  end

  def import_deals(io)
    pipeline = Pipeline.default_for(@workspace)
    stage = pipeline&.first_stage
    each_row(io) do |row, line|
      company = find_or_create_company(row["company"], fallback_name: row["name"])
      next add_error(line, "No default pipeline") unless pipeline && stage

      deal = @workspace.deals.new(
        name: row["name"],
        company: company,
        pipeline: pipeline,
        pipeline_stage: resolve_stage(pipeline, row["stage"]) || stage,
        value: row["value"],
        currency: row["currency"].presence || "EUR",
        probability: row["probability"],
        expected_close_date: row["expected_close_date"],
        owner: @user
      )
      deal.contacts << company.people.first if company.people.any?
      deal.tasks.build(title: "Follow up", due_on: 1.week.from_now.to_date, workspace: @workspace, assignee: @user)
      save_record(deal, line)
    end
    result
  end

  private

  def each_row(io)
    CSV.parse(io.read, headers: true).each_with_index do |row, index|
      yield row, index + 2
    end
  end

  def save_record(record, line)
    if record.save
      @created += 1
    else
      add_error(line, record.errors.full_messages.join(", "))
    end
  end

  def add_error(line, message)
    @errors << "Line #{line}: #{message}"
  end

  def result
    Result.new(created: @created, errors: @errors)
  end

  def find_or_create_company(name, fallback_name: nil)
    label = name.presence || fallback_name.presence || "Unknown"
    @workspace.companies.find_or_create_by!(name: label) do |company|
      company.owner = @user
    end
  end

  def resolve_stage(pipeline, stage_name)
    return nil if stage_name.blank?

    pipeline.pipeline_stages.find_by("LOWER(name) = ?", stage_name.downcase)
  end
end
