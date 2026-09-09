# Groups pipeline stages by name while preserving first-seen order across pipelines.
# Used when "All pipelines" is selected on dashboard, reports and the deals board.
class StageNameGroup
  Group = Data.define(:name, :stages) do
    def representative_stage = stages.first
    def stage_color = representative_stage.color
  end

  Segment = Data.define(:stage_id, :pipeline_name, :pipeline_id, :pipeline_position, :value, :color)

  def self.group(stages)
    new(stages).groups
  end

  def initialize(stages)
    @stages = Array(stages)
  end

  def groups
    @stages.each_with_object([]) do |stage, result|
      existing = result.find { |group| group.name == stage.name }
      if existing
        existing.stages << stage
      else
        result << Group.new(name: stage.name, stages: [ stage ])
      end
    end
  end

  def segments_for(group, counts_by_stage_id)
    group.stages.sort_by { |stage| [ stage.pipeline.position, stage.pipeline.id ] }.map do |stage|
      Segment.new(
        stage_id: stage.id,
        pipeline_name: stage.pipeline.name,
        pipeline_id: stage.pipeline_id,
        pipeline_position: stage.pipeline.position,
        value: counts_by_stage_id[stage.id] || 0,
        color: pipeline_bar_color(stage.pipeline.position)
      )
    end
  end

  def pipeline_bar_color(pipeline_position)
    self.class.pipeline_bar_colors[pipeline_position.to_i % self.class.pipeline_bar_colors.size]
  end

  # Saturated brand palette for stacked pipeline segments (safelist in application.css).
  # Uses 500–600 tones so segments stay legible on light and dark canvas backgrounds.
  def self.pipeline_bar_colors
    @pipeline_bar_colors ||= [
      "bg-hoki-600 dark:bg-hoki-400",
      "bg-copperfield-600 dark:bg-copperfield-400",
      "bg-chicago-600 dark:bg-chicago-400",
      "bg-golden-600 dark:bg-golden-500",
      "bg-green-600 dark:bg-green-500",
      "bg-red-600 dark:bg-red-500",
      "bg-hoki-500 dark:bg-hoki-300",
      "bg-copperfield-500 dark:bg-copperfield-300"
    ].freeze
  end
end
