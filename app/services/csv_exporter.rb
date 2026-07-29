require "csv"

class CsvExporter
  EXPORTERS = {
    "Person" => :export_people,
    "Company" => :export_companies,
    "Deal" => :export_deals
  }.freeze

  def self.export(record_type, scope:, custom_fields: [])
    new(scope: scope, custom_fields: custom_fields).public_send(EXPORTERS.fetch(record_type))
  end

  def initialize(scope:, custom_fields: [])
    @scope = scope
    @custom_fields = custom_fields
  end

  def export_people
    headers = %w[first_name last_name email phone job_title location company] + custom_field_headers
    CSV.generate do |csv|
      csv << headers
      @scope.includes(:company, custom_field_values: :custom_field).find_each do |person|
        csv << [
          person.first_name, person.last_name, person.email, person.phone,
          person.job_title, person.location, person.company&.name
        ] + custom_field_values(person)
      end
    end
  end

  def export_companies
    headers = %w[name domain industry employee_range location annual_revenue] + custom_field_headers
    CSV.generate do |csv|
      csv << headers
      @scope.includes(custom_field_values: :custom_field).find_each do |company|
        csv << [
          company.name, company.domain, company.industry, company.employee_range,
          company.location, company.annual_revenue
        ] + custom_field_values(company)
      end
    end
  end

  def export_deals
    headers = %w[name company stage value currency probability expected_close_date invoice_number] + custom_field_headers
    CSV.generate do |csv|
      csv << headers
      @scope.includes(:company, :pipeline_stage, custom_field_values: :custom_field).find_each do |deal|
        csv << [
          deal.name, deal.company&.name, deal.stage_label, deal.value, deal.currency,
          deal.probability, deal.expected_close_date, deal.invoice_number
        ] + custom_field_values(deal)
      end
    end
  end

  private

  def custom_field_headers
    @custom_fields.map(&:key)
  end

  def custom_field_values(record)
    hash = record.custom_fields_hash
    @custom_fields.map { |field| hash[field.key] }
  end
end
