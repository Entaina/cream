class Report < ApplicationRecord
  RECORD_TYPES = %w[Deal Person Company].freeze
  METRICS = %w[count sum_value avg_value].freeze
  VALUE_METRICS = %w[sum_value avg_value].freeze
  RANGES = %w[all month quarter year].freeze
  SCHEDULES = %w[none daily weekly monthly].freeze
  SCHEDULE_INTERVALS = { "daily" => 1.day, "weekly" => 1.week, "monthly" => 1.month }.freeze

  # Group-by dimensions available per record type.
  DIMENSIONS = {
    "Deal" => %w[stage owner month],
    "Person" => %w[owner company month],
    "Company" => %w[owner industry month]
  }.freeze

  belongs_to :workspace
  belongs_to :user
  belongs_to :pipeline, optional: true

  validates :name, :record_type, :metric, :group_by, :date_range, presence: true
  validates :record_type, inclusion: { in: RECORD_TYPES }
  validates :metric, inclusion: { in: METRICS }
  validates :date_range, inclusion: { in: RANGES }
  validates :schedule, inclusion: { in: SCHEDULES }
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
    { record_type: record_type, metric: metric, group_by: group_by, date_range: date_range, pipeline_id: pipeline_id }
  end

  def value_metric? = VALUE_METRICS.include?(metric)

  private

  def group_by_valid_for_type
    return if record_type.blank?

    allowed = DIMENSIONS[record_type] || []
    errors.add(:group_by, "is not valid for #{record_type}") unless allowed.include?(group_by)
  end

  def metric_valid_for_type
    return if metric == "count"

    errors.add(:metric, "is only available for deals") unless record_type == "Deal"
  end

  def pipeline_valid_for_type
    return if pipeline_id.blank?

    if record_type != "Deal"
      errors.add(:pipeline_id, "is only valid for deals")
    elsif !workspace.pipelines.exists?(id: pipeline_id)
      errors.add(:pipeline_id, "is not valid for this workspace")
    end
  end
end
