class Membership < ApplicationRecord
  ROLES = %w[admin sales_director salesperson].freeze
  ROLE_LABELS = {
    "admin" => "Admin",
    "sales_director" => "Director comercial",
    "salesperson" => "Vendedor"
  }.freeze
  SALES_BRIEFING_DAILY_REGENERATIONS_LIMIT = 5

  belongs_to :workspace
  belongs_to :user
  belongs_to :current_pipeline, class_name: "Pipeline", optional: true

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :workspace_id }
  validate :current_pipeline_belongs_to_workspace

  before_create :set_default_current_pipeline
  validate :ensure_not_demoting_last_admin, on: :update
  before_destroy :ensure_not_last_admin

  scope :admins, -> { where(role: "admin") }

  scope :search, ->(q) {
    if q.present?
      joins(:user).where(
        "users.name ILIKE :q OR users.email_address ILIKE :q",
        q: "%#{sanitize_sql_like(q)}%"
      )
    end
  }

  def admin?
    role == "admin"
  end

  def sales_director?
    role == "sales_director"
  end

  def salesperson?
    role == "salesperson"
  end

  def role_label
    ROLE_LABELS.fetch(role, role)
  end

  def last_admin?
    admin? && workspace.memberships.admins.count == 1
  end

  def sales_director_briefing_visible?
    sales_director_briefing_enabled? &&
      workspace.sales_director_enabled? &&
      CreamFeatures.enabled?(:sales_director) &&
      Ai::Configuration.configured?
  end

  def sales_briefing_regenerations_today
    reset_sales_briefing_regenerations_if_new_day!
    sales_briefing_regenerations_count
  end

  def can_regenerate_sales_briefing?
    sales_briefing_regenerations_today < SALES_BRIEFING_DAILY_REGENERATIONS_LIMIT
  end

  def sales_briefing_regenerations_remaining
    [ SALES_BRIEFING_DAILY_REGENERATIONS_LIMIT - sales_briefing_regenerations_today, 0 ].max
  end

  def record_sales_briefing_regeneration!
    reset_sales_briefing_regenerations_if_new_day!
    update!(
      sales_briefing_regenerations_count: sales_briefing_regenerations_count + 1,
      sales_briefing_regenerations_on: Date.current
    )
  end

  private

  def reset_sales_briefing_regenerations_if_new_day!
    return if sales_briefing_regenerations_on == Date.current

    update!(
      sales_briefing_regenerations_count: 0,
      sales_briefing_regenerations_on: Date.current
    )
  end

  def set_default_current_pipeline
    self.current_pipeline_id ||= Pipeline.default_for(workspace)&.id
  end

  def current_pipeline_belongs_to_workspace
    return if current_pipeline_id.blank?
    return if current_pipeline&.workspace_id == workspace_id

    errors.add(:current_pipeline, "must belong to the workspace")
  end

  def ensure_not_last_admin
    return if destroyed_by_association # cascading from workspace.destroy
    return unless last_admin?

    errors.add(:base, "Cannot remove the last admin from the workspace")
    throw(:abort)
  end

  def ensure_not_demoting_last_admin
    return unless role_changed? && role_was == "admin" && role != "admin"
    return unless workspace.memberships.admins.where.not(id: id).none?

    errors.add(:role, "cannot demote the last admin")
  end
end
