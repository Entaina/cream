class Pipeline < ApplicationRecord
  # Stages every workspace starts with (the classic sales funnel + probabilities).
  DEFAULT_STAGES = [
    { name: "Lead", color: "chicago", probability: 10 },
    { name: "Qualified", color: "hoki", probability: 25 },
    { name: "Proposal", color: "copperfield", probability: 50 },
    { name: "Negotiation", color: "golden", probability: 75 },
    { name: "Won", color: "green", probability: 100, won: true, closed: true },
    { name: "Lost", color: "red", probability: 0, closed: true }
  ].freeze

  CARD_FIELDS = {
    "value" => "Valor",
    "company" => "Empresa",
    "owner" => "Responsable",
    "expected_close_date" => "Fecha de cierre",
    "probability" => "Probabilidad",
    "contacts" => "Contactos",
    "products" => "Productos y ediciones"
  }.freeze

  belongs_to :workspace
  has_many :pipeline_stages, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :pipeline
  has_many :deals, dependent: :restrict_with_error

  accepts_nested_attributes_for :pipeline_stages, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:name].blank? }

  validates :name, presence: true
  validate :must_have_a_stage

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
      name: name.presence || "#{self.name} (copy)",
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
      .sort_by { |stage| [ stage.position.to_i, stage.id.to_i ] }
      .each_with_index { |stage, i| stage.position = i }
  end

  def normalize_card_fields
    self.card_fields = Array(card_fields).map(&:to_s).uniq & CARD_FIELDS.keys
  end

  def must_have_a_stage
    return if pipeline_stages.reject(&:marked_for_destruction?).any?

    errors.add(:base, "A pipeline needs at least one stage")
  end
end
