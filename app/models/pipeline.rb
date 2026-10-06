class Pipeline < ApplicationRecord
  # Stages every workspace starts with (the classic sales funnel + probabilities).
  DEFAULT_STAGES = [
    {name: "Lead", color: "chicago", probability: 10},
    {name: "Qualified", color: "hoki", probability: 25},
    {name: "Proposal", color: "copperfield", probability: 50},
    {name: "Negotiation", color: "golden", probability: 75},
    {name: "Won", color: "green", probability: 100, won: true, closed: true},
    {name: "Lost", color: "red", probability: 0, closed: true}
  ].freeze

  CARD_FIELD_KEYS = %w[
    value company owner expected_close_date probability execution_duration_days execution_starts_on execution_ends_on
    payment_method payment_on invoice_number contacts products
  ].freeze

  belongs_to :workspace
  has_many :pipeline_stages, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :pipeline
  has_many :deals, dependent: :restrict_with_error

  accepts_nested_attributes_for :pipeline_stages, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:name].blank? }

  validates :name, presence: true
  validate :must_have_a_stage
  validate :removed_stages_not_used_by_lead_forms
  validate :removed_stages_without_deals

  before_validation :assign_workspace_to_stages
  before_validation :normalize_card_fields
  before_save :renumber_stages

  scope :ordered, -> { order(:position, :id) }

  # The pipeline used for new deals: the one flagged default, else the first.
  def self.default_for(workspace)
    workspace.pipelines.where(default_pipeline: true).ordered.first ||
      workspace.pipelines.ordered.first
  end

  # Seed a fresh workspace with the default "Ventas" pipeline and stages.
  def self.create_default!(workspace)
    workspace.pipelines.create!(name: "Ventas", default_pipeline: true, position: 0,
      pipeline_stages: DEFAULT_STAGES.each_with_index.map { |attrs, i|
        PipelineStage.new(attrs.reverse_merge(won: false, closed: false).merge(position: i, workspace: workspace))
      })
  end

  def first_stage = pipeline_stages.ordered.first

  def show_card_field?(field) = card_fields.include?(field.to_s)

  def self.card_field_label(key)
    case key
    when "value" then I18n.t("records.fields.value")
    when "company" then I18n.t("records.fields.company")
    when "owner" then I18n.t("records.fields.owner")
    when "expected_close_date" then I18n.t("records.fields.close_date")
    when "probability" then I18n.t("records.fields.probability")
    when "execution_duration_days" then I18n.t("records.fields.execution_duration")
    when "execution_starts_on" then I18n.t("records.fields.execution_starts_on")
    when "execution_ends_on" then I18n.t("records.fields.execution_ends_on")
    when "payment_method" then I18n.t("records.fields.payment_method")
    when "payment_on" then I18n.t("records.fields.payment_on")
    when "invoice_number" then I18n.t("records.fields.invoice_number")
    when "contacts" then I18n.t("records.fields.contacts")
    when "products" then I18n.t("pipelines.card_fields.products")
    else key.humanize
    end
  end

  def self.card_field_options
    CARD_FIELD_KEYS.map { |key| [card_field_label(key), key] }
  end

  # Reorder stages by id list (must include every stage exactly once).
  def reorder_stages!(stage_ids)
    ids = Array(stage_ids).map(&:to_i)
    owned = pipeline_stages.pluck(:id)
    return false unless ids.sort == owned.sort

    transaction do
      ids.each_with_index { |id, i| pipeline_stages.find(id).update_column(:position, i) }
    end
    true
  end

  # Build an unsaved copy with the same stages (structure only — no deals, not default).
  def duplicate(name: nil)
    copy = workspace.pipelines.new(
      name: name.presence || "#{self.name}#{I18n.t("pipelines.duplicate_name_suffix")}",
      position: workspace.pipelines.count,
      default_pipeline: false,
      card_fields: card_fields
    )
    pipeline_stages.ordered.each do |stage|
      copy.pipeline_stages.build(
        name: stage.name, color: stage.color, probability: stage.probability,
        position: stage.position, won: stage.won, closed: stage.closed, workspace: workspace
      )
    end
    copy
  end

  private

  def assign_workspace_to_stages
    pipeline_stages.each { |stage| stage.workspace ||= workspace }
  end

  def renumber_stages
    pipeline_stages.reject(&:marked_for_destruction?)
      .sort_by { |stage| [stage.position.to_i, stage.id.to_i] }
      .each_with_index { |stage, i| stage.position = i }
  end

  def normalize_card_fields
    self.card_fields = Array(card_fields).map(&:to_s).uniq & CARD_FIELD_KEYS
  end

  def must_have_a_stage
    return if pipeline_stages.reject(&:marked_for_destruction?).any?

    errors.add(:base, I18n.t("pipelines.validation.needs_stage"))
  end

  def removed_stages_not_used_by_lead_forms
    pipeline_stages.select(&:marked_for_destruction?).each do |stage|
      next if stage.new_record?

      names = stage.lead_forms.order(:name).pluck(:name)
      next if names.empty?

      errors.add(:base, I18n.t("pipelines.validation.stage_used_by_lead_forms", stage: stage.name, forms: names.to_sentence))
    end
  end

  def removed_stages_without_deals
    pipeline_stages.select(&:marked_for_destruction?).each do |stage|
      next if stage.new_record?

      count = stage.deals.count
      next if count.zero?

      errors.add(:base, I18n.t("pipelines.validation.stage_has_deals", stage: stage.name, count: count))
    end
  end
end
