class ReportRunner
  METRIC_LABELS = {
    "count" => "Count",
    "sum_value" => "Total value",
    "avg_value" => "Average value"
  }.freeze

  Row = Data.define(:key, :label, :value, :color)
  Result = Data.define(:rows, :metric, :metric_label, :total, :max)

  def initialize(workspace:, record_type:, metric:, group_by:, date_range:, pipeline_id: nil, include_closed: false)
    @workspace = workspace
    @record_type = record_type
    @metric = metric
    @group_by = group_by
    @date_range = date_range
    @pipeline_id = pipeline_id
    @include_closed = include_closed
  end

  def run
    grouped = aggregate(grouped_scope)
    rows = grouped.map { |key, value|
      Row.new(key: key, label: label_for(key), value: value.to_f.round(2), color: color_for(key))
    }
    rows = sort_rows(rows)

    Result.new(
      rows: rows,
      metric: @metric,
      metric_label: METRIC_LABELS.fetch(@metric),
      total: rows.sum(&:value),
      max: rows.map(&:value).max || 0
    )
  end

  private

  def model = @record_type.constantize

  def base_scope
    scope = @workspace.public_send(@record_type.tableize)
    start = range_start
    scope = scope.where(model.arel_table[:created_at].gteq(start)) if start
    scope = scope.where(pipeline_id: @pipeline_id) if @pipeline_id && @record_type == "Deal"
    scope
  end

  def range_start
    case @date_range
    when "month" then Time.current.beginning_of_month
    when "quarter" then Time.current.beginning_of_quarter
    when "year" then Time.current.beginning_of_year
    end
  end

  def grouped_scope
    scope = base_scope
    scope = scope.open_deals if @group_by == "stage" && !@include_closed
    case @group_by
    when "owner" then scope.group(:owner_id)
    when "stage" then scope.group(:pipeline_stage_id)
    when "industry" then scope.group(:industry)
    when "company" then scope.group(:company_id)
    when "month" then scope.group(Arel.sql("date_trunc('month', #{model.table_name}.created_at)"))
    else scope.group(:owner_id)
    end
  end

  def aggregate(scope)
    case @metric
    when "sum_value" then scope.sum(:value)
    when "avg_value" then scope.average(:value)
    else scope.count
    end
  end

  # Months are kept in chronological order; everything else is ranked by value.
  def sort_rows(rows)
    @group_by == "month" ? rows : rows.sort_by { |row| -row.value }
  end

  def label_for(key)
    case @group_by
    when "owner" then owner_names[key] || "Unassigned"
    when "stage" then stage_names[key] || "—"
    when "company" then company_names[key] || "—"
    when "industry" then key.presence || "—"
    when "month" then key ? key.to_date.strftime("%b %Y") : "—"
    else key.to_s
    end
  end

  def owner_names
    @owner_names ||= @workspace.users.pluck(:id, :name).to_h
  end

  def color_for(key)
    return unless @group_by == "stage"

    stage_colors[key]
  end

  def stage_names
    @stage_names ||= @workspace.pipeline_stages.pluck(:id, :name).to_h
  end

  def stage_colors
    @stage_colors ||= @workspace.pipeline_stages.pluck(:id, :color).to_h
  end

  def company_names
    @company_names ||= @workspace.companies.pluck(:id, :name).to_h
  end
end
