class Report < ApplicationRecord
  RECORD_TYPES = %w[Deal Person Company Campaign LeadSubmission].freeze
  METRICS = %w[count sum_value avg_value].freeze
  VALUE_METRICS = %w[sum_value avg_value].freeze
  RANGES = %w[all month quarter year].freeze
  SCHEDULES = %w[none daily weekly monthly].freeze
  SCHEDULE_INTERVALS = {"daily" => 1.day, "weekly" => 1.week, "monthly" => 1.month}.freeze

  # Group-by dimensions available per record type.
  DIMENSIONS = {
    "Deal" => %w[stage owner month utm_source utm_medium utm_campaign],
    "Person" => %w[owner company month lifecycle_stage utm_source],
    "Company" => %w[owner industry month],
    "Campaign" => %w[status month utm_source utm_medium utm_campaign],
    "LeadSubmission" => %w[month utm_source utm_medium utm_campaign]
  }.freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :pipeline, optional: true

  validates :name, :record_type, :metric, :group_by, :date_range, presence: true
  validates :record_type, inclusion: {in: RECORD_TYPES}
  validates :metric, inclusion: {in: METRICS}
  validates :date_range, inclusion: {in: RANGES}
  validates :schedule, inclusion: {in: SCHEDULES}
  validate :group_by_valid_for_type
  validate :metric_valid_for_type
  validate :pipeline_valid_for_type

  scope :ordered, -> { order(:name, :id) }
  scope :visible_to, ->(user) { where(user: user).or(where(shared: true)) }
  scope :scheduled, -> { where.not(schedule: "none") }

  def scheduled? = schedule != "none"

  # Whether a scheduled report is due to be sent again given its interval.
  def due_to_send?
    interval = SCHEDULE_INTERVALS[schedule]
    return false unless interval

    last_sent_at.nil? || last_sent_at < interval.ago
  end

  def config_params
    {record_type: record_type, metric: metric, group_by: group_by, date_range: date_range, pipeline_id: pipeline_id}
  end

  def value_metric? = VALUE_METRICS.include?(metric)

  def self.metric_label(metric)
    I18n.t("reports.metrics.#{metric}", default: metric.to_s.humanize)
  end

  def self.group_by_label(group_by)
    I18n.t("reports.group_by.#{group_by}", default: group_by.to_s.humanize)
  end

  def self.record_type_label(record_type)
    I18n.t("reports.record_types.#{record_type}", default: record_type.to_s)
  end

  def self.date_range_label(date_range)
    I18n.t("reports.date_ranges.#{date_range}", default: date_range.to_s.humanize)
  end

  private

  def group_by_valid_for_type
    return if record_type.blank?

    allowed = DIMENSIONS[record_type] || []
    errors.add(:group_by, :group_by_invalid, record_type: record_type) unless allowed.include?(group_by)
  end

  def metric_valid_for_type
    return if metric == "count"

    errors.add(:metric, :metric_deals_only) unless record_type == "Deal"
  end

  def pipeline_valid_for_type
    return if pipeline_id.blank?

    if record_type != "Deal"
      errors.add(:pipeline_id, :pipeline_id_deals_only)
    elsif !workspace.pipelines.exists?(id: pipeline_id)
      errors.add(:pipeline_id, :pipeline_id_invalid_workspace)
    end
  end
end
