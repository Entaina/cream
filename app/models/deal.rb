class Deal < ApplicationRecord
  include CrmRecord

  attr_accessor :duplicating

  has_paper_trail meta: {workspace_id: :workspace_id}

  belongs_to :company
  belongs_to :partner, class_name: "Company", optional: true
  belongs_to :pipeline
  belongs_to :pipeline_stage
  belongs_to :campaign, optional: true

  has_many :deal_contacts, dependent: :destroy, inverse_of: :deal
  has_many :contacts, through: :deal_contacts, source: :person

  has_many :deal_products, dependent: :destroy, inverse_of: :deal
  has_many :products, through: :deal_products

  has_many :deal_accesses, dependent: :destroy
  has_many :collaborators, through: :deal_accesses, source: :user

  has_many :stripe_payments, dependent: :nullify
  has_many :suggested_stripe_payments, class_name: "StripePayment",
    foreign_key: :suggested_deal_id, dependent: :nullify, inverse_of: :suggested_deal
  has_many :lead_submissions, dependent: :destroy
  has_many :bookings, dependent: :nullify
  accepts_nested_attributes_for :deal_products, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:product_id].blank? }
  accepts_nested_attributes_for :tasks,
    reject_if: ->(attrs) { attrs[:title].blank? && attrs[:due_on].blank? }

  validates :name, presence: true
  validates :value, numericality: {greater_than_or_equal_to: 0}
  validates :probability, numericality: {in: 0..100}, allow_nil: true
  validates :execution_duration_days, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  validate :stage_belongs_to_pipeline
  validate :stage_entry_conditions_met, if: -> { persisted? && will_save_change_to_pipeline_stage_id? }
  validate :contacts_belong_to_company
  validate :partner_differs_from_company
  validate :has_a_future_task, on: :create, unless: :duplicating

  before_validation :set_default_pipeline_stage, on: :create
  before_validation :assign_task_defaults

  scope :search, ->(q) {
    next if q.blank?
    left_outer_joins(:company)
      .where(
        "deals.name ILIKE :q OR companies.name ILIKE :q OR deals.invoice_number ILIKE :q",
        q: "%#{sanitize_sql_like(q)}%"
      )
  }
  scope :open_deals, -> { joins(:pipeline_stage).where(pipeline_stages: {closed: false}) }
  scope :won, -> { joins(:pipeline_stage).where(pipeline_stages: {won: true}) }
  # Deals a payment can reasonably belong to: anything not lost (open or won).
  scope :linkable, -> { joins(:pipeline_stage).where("pipeline_stages.closed = false OR pipeline_stages.won = true") }
  scope :by_stage, ->(stage_id) { where(pipeline_stage_id: stage_id).order(:position, :id) }
  scope :sorted_by_stage_order, ->(direction = :asc) {
    dir = (direction.to_s == "desc") ? "DESC" : "ASC"
    joins(:pipeline_stage).order(Arel.sql("pipeline_stages.position #{dir}, deals.position #{dir}, deals.id #{dir}"))
  }
  scope :sorted_by_next_task, ->(direction = :asc) {
    dir = (direction.to_s == "desc") ? "DESC" : "ASC"
    joins(<<~SQL.squish)
      LEFT JOIN LATERAL (
        SELECT MIN(tasks.due_on) AS next_due_on
        FROM tasks
        WHERE tasks.taskable_type = 'Deal'
          AND tasks.taskable_id = deals.id
          AND tasks.completed_at IS NULL
          AND tasks.due_on IS NOT NULL
      ) next_task ON true
    SQL
      .order(Arel.sql("next_task.next_due_on #{dir} NULLS LAST, deals.id #{dir}"))
  }

  def self.filter_by(scope, filters)
    filters = filters.symbolize_keys
    scope = scope.search(filters[:q]) if filters[:q].present?
    scope = scope.where(pipeline_stage_id: filters[:stage]) if filters[:stage].present?
    apply_extra_filters(scope, filters)
  end

  def self.apply_extra_filters(scope, filters)
    filters = filters.symbolize_keys

    if filters[:product_id].present? || filters[:edition_id].present?
      scope = scope.joins(:deal_products)
      scope = scope.where(deal_products: {product_id: filters[:product_id]}) if filters[:product_id].present?
      scope = scope.where(deal_products: {edition_id: filters[:edition_id]}) if filters[:edition_id].present?
      scope = scope.distinct
    end

    if filters[:first_contact_from].present? || filters[:first_contact_to].present?
      scope = scope.joins(:contacts)
      scope = scope.where("people.first_contact_on >= ?", filters[:first_contact_from]) if filters[:first_contact_from].present?
      scope = scope.where("people.first_contact_on <= ?", filters[:first_contact_to]) if filters[:first_contact_to].present?
      scope = scope.distinct
    end

    scope = ListFilters.apply_owner(scope, filters[:owner_id]) if filters[:owner_id].present?
    ListFilters.apply_created_at(scope, filters)
  end

  def stage_label = pipeline_stage&.name
  def stage_color = pipeline_stage&.color

  # Used by field conditions (alerts, stage entry rules): deal is not in a closed stage.
  def open
    pipeline_stage.present? && !pipeline_stage.closed?
  end

  def display_name = name

  def next_pending_task
    pending = tasks.select { |t| t.completed_at.nil? }
    pending.min_by { |t| [t.due_on ? 0 : 1, t.due_on || Date.new(9999, 12, 31), t.id] }
  end

  def pending_task_indicator_status
    pending = tasks.select { |t| t.completed_at.nil? }
    return nil if pending.empty?

    pending.any?(&:overdue?) ? :overdue : :on_track
  end

  def initials
    name.split.map { |w| w[0] }.grep(/[[:alnum:]]/).first(2).join.upcase
  end

  def tracked_ignored_attributes = %w[pipeline_id pipeline_stage_id value]

  # Accepts a PipelineStage, its id, or its name (within the deal's pipeline).
  def move_to_stage!(stage, position: nil)
    target = resolve_stage(stage)
    old_stage = pipeline_stage
    old_pipeline = pipeline
    update!(pipeline_stage: target, pipeline: target.pipeline,
      position: position || (workspace.deals.where(pipeline_stage_id: target.id).maximum(:position) || 0) + 1)
    reposition_in_stage!(target, position) unless position.nil?
    if old_stage != target
      track_activity("stage_changed", metadata: {from: old_stage&.name, to: target.name, won: target.won?})
    end
    if old_stage != target
      if old_pipeline.id != target.pipeline_id
        track_activity("pipeline_changed", metadata: {from: old_pipeline.name, to: target.pipeline.name})
      end
      if CreamFeatures.enabled?(:webhooks)
        WebhookDispatcher.dispatch(
          workspace: workspace,
          event: "deal.stage_changed",
          payload: {deal_id: id, from: old_stage&.name, to: target.name, workspace_id: workspace_id}
        )
      end
      run_automations("deal.stage_changed", metadata: {"to" => target.name})
      StageTriggers::Dispatcher.call(deal: self, stage: target, user: Current.user) if CreamFeatures.enabled?(:stage_triggers)
      if CreamFeatures.enabled?(:slack_integrations)
        SlackNotifier.notify(workspace: workspace, event: "deal.stage_changed", message: "Deal #{name} moved to #{target.name}")
      end
    end
  end

  # Move the deal to another pipeline, landing on that pipeline's initial stage.
  def move_to_pipeline!(target)
    target = workspace.pipelines.find(target) unless target.is_a?(Pipeline)
    return if target.id == pipeline_id

    old_pipeline = pipeline
    first = target.first_stage
    update!(pipeline: target, pipeline_stage: first,
      position: (workspace.deals.where(pipeline_stage_id: first.id).maximum(:position) || 0) + 1)
    track_activity("pipeline_changed", metadata: {from: old_pipeline&.name, to: target.name})
  end

  # Recompute the deal value as the sum of its product line subtotals.
  def recalculate_value!
    update_column(:value, deal_products.sum("quantity * unit_price"))
  end

  # Build an unsaved copy in the same workspace (scalar fields, contacts, custom fields, pending tasks).
  def duplicate
    copy = workspace.deals.new(
      name: "#{name} (copia)",
      company: company,
      partner: partner,
      pipeline: pipeline,
      pipeline_stage: pipeline_stage,
      value: value, currency: currency,
      probability: probability,
      expected_close_date: expected_close_date,
      execution_duration_days: execution_duration_days,
      owner: owner
    )
    copy.duplicating = true
    copy.contact_ids = contact_ids
    copy.custom_fields = filled_custom_fields_hash
    tasks.pending.each do |task|
      copy.tasks.build(title: task.title, due_on: task.due_on, assignee: task.assignee)
    end
    copy
  end

  private

  def filled_custom_fields_hash
    custom_fields_hash.select do |_key, value|
      !value.nil? && !(value.is_a?(String) && value.blank?) && !(value.is_a?(Array) && value.empty?)
    end
  end

  def reposition_in_stage!(target, index)
    ids = workspace.deals.where(pipeline_stage_id: target.id)
      .where.not(id: id).order(:position, :id).pluck(:id)
    ids.insert([index, ids.size].min, id)
    ids.each_with_index { |deal_id, i| workspace.deals.where(id: deal_id).update_all(position: i) }
  end

  def resolve_stage(stage)
    return stage if stage.is_a?(PipelineStage)

    if stage.to_s.match?(/\A\d+\z/)
      found = workspace.pipeline_stages.find_by(id: stage)
      return found if found
    end

    scope = pipeline&.pipeline_stages || PipelineStage.where(workspace_id: workspace_id)
    found = scope.where("name ILIKE ?", stage.to_s).first
    found || raise(ActiveRecord::RecordNotFound, "Unknown pipeline stage: #{stage}")
  end

  def set_default_pipeline_stage
    if pipeline_stage
      self.pipeline ||= pipeline_stage.pipeline
    elsif pipeline
      self.pipeline_stage ||= pipeline.first_stage
    elsif workspace
      self.pipeline ||= Pipeline.default_for(workspace)
      self.pipeline_stage ||= pipeline&.first_stage
    end
  end

  def stage_belongs_to_pipeline
    return if pipeline_stage.nil? || pipeline.nil?

    errors.add(:pipeline_stage, :must_belong_to_selected_pipeline) if pipeline_stage.pipeline_id != pipeline_id
  end

  def stage_entry_conditions_met
    stage = pipeline_stage
    return if stage.nil?

    failed = stage.stage_conditions.active.ordered.reject { |condition| condition.met?(self) }
    return if failed.empty?

    requirements = failed.map(&:describe_requirement).join("; ")
    errors.add(:base, I18n.t("field_conditions.stage_move_blocked", stage: stage.name, requirements: requirements))
  end

  def contacts_belong_to_company
    return if company.nil?

    allowed = [company_id, partner_id].compact
    outsiders = live_contacts.reject { |person| allowed.include?(person.company_id) }
    return if outsiders.empty?

    names = [company&.name, partner&.name].compact.to_sentence
    errors.add(:base, :contacts_must_belong_to_companies, names: names)
  end

  def partner_differs_from_company
    return if partner_id.blank? || company_id.blank?

    errors.add(:partner, :must_differ_from_client_company) if partner_id == company_id
  end

  # On creation a deal must define a next action: a task due today or later.
  def has_a_future_task
    valid = tasks.reject(&:marked_for_destruction?).any? { |t| t.due_on.present? && t.due_on >= Date.current }
    errors.add(:base, :needs_next_action) unless valid
  end

  def live_contacts
    (contacts.to_a + deal_contacts.reject(&:marked_for_destruction?).map(&:person)).compact.uniq
  end

  def assign_task_defaults
    tasks.each do |task|
      next if task.persisted?

      task.workspace ||= workspace
      task.user ||= owner || Current.user
      task.assignee ||= task.user
    end
  end
end
