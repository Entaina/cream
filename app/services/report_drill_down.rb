class ReportDrillDown
  def initialize(config:, row:, workspace:)
    @config = config.symbolize_keys
    @row = row
    @workspace = workspace
  end

  def path
    helpers.public_send(:"#{record_type.tableize}_path", query_params)
  end

  private

  def helpers = Rails.application.routes.url_helpers

  def record_type = @config.fetch(:record_type)

  def query_params
    params = group_filter
    params.merge!(month_filter) if @config[:group_by] == "month"
    params.merge!(date_range_filter) if @config[:group_by] != "month"
    params[:pipeline_id] = pipeline_param if record_type == "Deal"
    params[:closed] = "1" if needs_closed?
    params.compact
  end

  def group_filter
    case [record_type, @config[:group_by]]
    when ["Deal", "stage"]
      {stage: @row.key}
    when ["Deal", "owner"], ["Person", "owner"], ["Company", "owner"]
      {owner_id: @row.key.nil? ? ListFilters::NONE : @row.key}
    when ["Person", "company"]
      {company_id: @row.key.nil? ? ListFilters::NONE : @row.key}
    when ["Company", "industry"]
      {industry: @row.key.blank? ? ListFilters::NONE : @row.key}
    else
      {}
    end
  end

  def month_filter
    return {} unless @row.key

    month_start = @row.key.to_date.beginning_of_month
    {created_from: month_start, created_to: month_start.end_of_month}
  end

  def date_range_filter
    start = range_start
    return {} unless start

    {created_from: start.to_date}
  end

  def range_start
    case @config[:date_range]
    when "month" then Time.current.beginning_of_month
    when "quarter" then Time.current.beginning_of_quarter
    when "year" then Time.current.beginning_of_year
    end
  end

  def pipeline_param
    @config[:pipeline_id].presence || "all"
  end

  def needs_closed?
    return true if @config[:include_closed]
    return false unless @config[:group_by] == "stage" && @row.key

    @workspace.pipeline_stages.find_by(id: @row.key)&.closed?
  end
end
