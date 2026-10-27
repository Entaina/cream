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

  FORMULA_PREFIXES = /\A[=+\-@]/

  def initialize(scope:, custom_fields: [])
    @scope = scope
    @custom_fields = custom_fields
  end

  def self.escape_formula(value)
    return value unless value.is_a?(String) && value.match?(FORMULA_PREFIXES)

    "'#{value}"
  end

  def export_people
    headers = %w[first_name last_name email phone job_title location company] + custom_field_headers
    CSV.generate do |csv|
      csv << headers
      @scope.includes(:company, custom_field_values: :custom_field).find_each do |person|
        csv << [
          person.first_name, person.last_name, person.email, person.phone,
          person.job_title, person.location, person.company&.name
        ].map { |cell| self.class.escape_formula(cell) } + custom_field_values(person).map { |cell| self.class.escape_formula(cell) }
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
        ].map { |cell| self.class.escape_formula(cell) } + custom_field_values(company).map { |cell| self.class.escape_formula(cell) }
      end
    end
  end

  def export_deals
    headers = %w[name company stage value currency probability expected_close_date execution_duration_days
      execution_starts_on execution_ends_on payment_method payment_on invoice_number] + custom_field_headers
    CSV.generate do |csv|
      csv << headers
      @scope.includes(:company, :pipeline_stage, custom_field_values: :custom_field).find_each do |deal|
        csv << [
          deal.name, deal.company&.name, deal.stage_label, deal.value, deal.currency,
          deal.probability, deal.expected_close_date, deal.execution_duration_days,
          deal.execution_starts_on, deal.execution_ends_on, deal.payment_method, deal.payment_on, deal.invoice_number
        ].map { |cell| self.class.escape_formula(cell) } + custom_field_values(deal).map { |cell| self.class.escape_formula(cell) }
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
