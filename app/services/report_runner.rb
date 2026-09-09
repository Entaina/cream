class ReportRunner
  METRIC_LABELS = {
    "count" => "Count",
    "sum_value" => "Total value",
    "avg_value" => "Average value"
  }.freeze

  UTM_COLUMNS = {
    "utm_source" => :utm_source,
    "utm_medium" => :utm_medium,
    "utm_campaign" => :utm_campaign
  }.freeze

  LEAD_SUBMISSION_UTM_SQL = {
    "utm_source" => Arel.sql("lead_submissions.metadata->>'utm_source'"),
    "utm_medium" => Arel.sql("lead_submissions.metadata->>'utm_medium'"),
    "utm_campaign" => Arel.sql("lead_submissions.metadata->>'utm_campaign'")
  }.freeze

  PERSON_UTM_SQL = {
    "utm_source" => Arel.sql("(SELECT lead_submissions.metadata->>'utm_source' FROM lead_submissions WHERE lead_submissions.person_id = people.id ORDER BY lead_submissions.created_at ASC LIMIT 1)"),
    "utm_medium" => Arel.sql("(SELECT lead_submissions.metadata->>'utm_medium' FROM lead_submissions WHERE lead_submissions.person_id = people.id ORDER BY lead_submissions.created_at ASC LIMIT 1)"),
    "utm_campaign" => Arel.sql("(SELECT lead_submissions.metadata->>'utm_campaign' FROM lead_submissions WHERE lead_submissions.person_id = people.id ORDER BY lead_submissions.created_at ASC LIMIT 1)")
  }.freeze

  Row = Data.define(:key, :label, :value, :color, :segments)
  Result = Data.define(:rows, :metric, :metric_label, :total, :max, :all_pipelines_stage_chart)

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
    if all_pipelines_stage_grouping?
      rows = build_all_pipelines_stage_rows(grouped)
    else
      rows = grouped.map { |key, value|
        Row.new(key: key, label: label_for(key), value: value.to_f.round(2), color: color_for(key), segments: nil)
      }
    end
    rows = sort_rows(rows)

    Result.new(
      rows: rows,
      metric: @metric,
      metric_label: METRIC_LABELS.fetch(@metric),
      total: rows.sum(&:value),
      max: rows.map(&:value).max || 0,
      all_pipelines_stage_chart: all_pipelines_stage_grouping?
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
    scope = scope.open_deals if @group_by == "stage" && !@include_closed && @record_type == "Deal"
    case @group_by
    when "owner" then scope.group(:owner_id)
    when "stage" then scope.group(:pipeline_stage_id)
    when "industry" then scope.group(:industry)
    when "company" then scope.group(:company_id)
    when "month" then scope.group(Arel.sql("date_trunc('month', #{model.table_name}.created_at)"))
    when "lifecycle_stage" then scope.group(:lifecycle_stage)
    when "status" then scope.group(:status)
    when "utm_source", "utm_medium", "utm_campaign" then utm_grouped_scope(scope, @group_by)
    else scope.group(:owner_id)
    end
  end

  def utm_grouped_scope(scope, field)
    case @record_type
    when "Deal"
      scope.left_joins(:campaign).group(Campaign.arel_table[UTM_COLUMNS.fetch(field)])
    when "LeadSubmission"
      scope.group(LEAD_SUBMISSION_UTM_SQL.fetch(field))
    when "Person"
      scope.group(PERSON_UTM_SQL.fetch(field))
    when "Campaign"
      scope.group(UTM_COLUMNS.fetch(field))
    else
      scope.group(:owner_id)
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
    when "stage" then stage_labels[key] || "—"
    when "company" then company_names[key] || "—"
    when "industry" then key.presence || "—"
    when "month" then key ? key.to_date.strftime("%b %Y") : "—"
    when "lifecycle_stage" then key.presence || "—"
    when "status" then key.to_s.humanize
    when "utm_source", "utm_medium", "utm_campaign" then key.presence || "—"
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

  def stage_labels
    @stage_labels ||= @workspace.pipeline_stages.pluck(:id, :name).to_h
  end

  def stage_colors
    @stage_colors ||= @workspace.pipeline_stages.pluck(:id, :color).to_h
  end

  def company_names
    @company_names ||= @workspace.companies.pluck(:id, :name).to_h
  end

  def all_pipelines_stage_grouping?
    @record_type == "Deal" && @group_by == "stage" && @pipeline_id.blank?
  end

  def build_all_pipelines_stage_rows(grouped)
    counts = grouped.transform_values { |value| value.to_f.round(2) }
    stages = visible_stages_for_chart
    grouper = StageNameGroup.new(stages)
    grouper.groups.filter_map do |group|
      segments = grouper.segments_for(group, counts)
      total = segments.sum(&:value)
      next if total.zero?

      Row.new(key: group.name, label: group.name, value: total, color: group.stage_color, segments: segments)
    end
  end

  def visible_stages_for_chart
    stages = @workspace.pipeline_stages.ordered_across_pipelines.includes(:pipeline).to_a
    @include_closed ? stages : stages.reject(&:closed?)
  end
end
