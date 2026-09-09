module StageChartHelper
  def stage_chart_groups(stages, counts_by_stage_id)
    grouper = StageNameGroup.new(stages)
    grouper.groups.map do |group|
      segments = grouper.segments_for(group, counts_by_stage_id)
      total = segments.sum(&:value)
      {
        name: group.name,
        color: group.stage_color,
        total: total,
        segments: segments
      }
    end
  end

  def all_pipelines_stage_chart?(pipeline: current_pipeline, config: nil)
    if config
      config[:record_type] == "Deal" && config[:group_by] == "stage" && config[:pipeline_id].blank?
    else
      pipeline.nil?
    end
  end
end
