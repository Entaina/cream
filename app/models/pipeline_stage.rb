class PipelineStage < ApplicationRecord
  COLORS = %w[chicago hoki copperfield golden green red].freeze

  belongs_to :pipeline
  belongs_to :workspace
  has_many :deals, dependent: :restrict_with_error
  has_many :lead_forms, dependent: :restrict_with_error
  has_many :stage_triggers, dependent: :destroy
  has_many :stage_field_formats, dependent: :destroy
  has_many :stage_conditions, dependent: :destroy

  validates :name, presence: true
  validates :color, inclusion: {in: COLORS}
  validates :probability, numericality: {only_integer: true, in: 0..100}

  scope :ordered, -> { order(:position, :id) }
  scope :ordered_across_pipelines, -> {
    joins(:pipeline).includes(:pipeline)
      .order(Arel.sql("pipelines.position, pipelines.id, pipeline_stages.position, pipeline_stages.id"))
  }

  def open? = !closed?
end
