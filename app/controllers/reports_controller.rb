require "csv"

class ReportsController < ApplicationController
  include RequiresFeature
  requires_feature :reports
  requires_workspace_feature :reports
  skip_after_action :verify_policy_scoped

  def index
    authorize :report, :index?
    @pipelines = current_workspace.pipelines.ordered
    @config = report_config
    @result = ReportRunner.new(workspace: current_workspace, **@config).run

    respond_to do |format|
      format.html { @reports = policy_scope(current_workspace.reports).visible_to(current_user).ordered }
      format.csv { send_data report_csv, filename: report_filename, type: "text/csv" }
    end
  end

  def create
    @report = current_workspace.reports.new(report_params.merge(user: current_user))
    authorize @report

    if @report.save
      redirect_to reports_path(@report.config_params), notice: "Report saved."
    else
      redirect_to reports_path(@report.config_params), alert: @report.errors.full_messages.to_sentence
    end
  end

  def update
    report = policy_scope(current_workspace.reports).find(params[:id])
    authorize report
    report.update(report_params)
    redirect_to reports_path, notice: "Report updated."
  end

  def destroy
    report = policy_scope(current_workspace.reports).find(params[:id])
    authorize report
    report.destroy
    redirect_to reports_path, notice: "Report deleted."
  end

  private

  def report_params
    params.require(:report).permit(:name, :record_type, :metric, :group_by, :date_range, :shared, :schedule, :pipeline_id)
  end

  def report_csv
    CSV.generate do |csv|
      csv << [ @config[:group_by], @result.metric_label ]
      @result.rows.each { |row| csv << [ row.label, row.value ] }
    end
  end

  def report_filename
    "report-#{@config[:record_type].downcase}-#{@config[:metric]}-#{Date.current}.csv"
  end

  # Sanitises the builder params into a valid config, falling back to defaults so
  # an unknown/incompatible combination can never blow up ReportRunner.
  def report_config
    record_type = params[:record_type].presence_in(Report::RECORD_TYPES) || "Deal"
    dimensions = Report::DIMENSIONS.fetch(record_type)
    metric = params[:metric].presence_in(metrics_for(record_type)) || "count"
    group_by = params[:group_by].presence_in(dimensions) || dimensions.first
    date_range = params[:date_range].presence_in(Report::RANGES) || "all"
    pipeline_id = sanitized_pipeline_id(record_type)
    include_closed = show_closed?
    { record_type: record_type, metric: metric, group_by: group_by, date_range: date_range,
      pipeline_id: pipeline_id, include_closed: include_closed }
  end

  def sanitized_pipeline_id(record_type)
    return nil unless record_type == "Deal"

    if params[:pipeline_id].present?
      pipeline_id = params[:pipeline_id]
      return current_workspace.pipelines.exists?(id: pipeline_id) ? pipeline_id.to_i : nil
    end

    return nil if params.key?(:pipeline_id)

    current_pipeline&.id
  end

  def metrics_for(record_type)
    record_type == "Deal" ? Report::METRICS : %w[count]
  end
end
