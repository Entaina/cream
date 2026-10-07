# frozen_string_literal: true

# Deal pipeline stage badge; when the user may move the deal, opens a dropdown of stages.
class DealStageComponent < ViewComponent::Base
  StageOption = Data.define(:stage, :current, :blocked, :blocked_title)

  attr_reader :deal, :wrapper_id

  def initialize(deal:, editable: nil, wrapper_id: nil)
    @deal = deal
    @editable_param = editable
    @wrapper_id = wrapper_id
  end

  def before_render
    @editable = @editable_param.nil? ? helpers.policy(deal).move? : @editable_param
  end

  def editable?
    @editable
  end

  def render?
    deal.pipeline_stage.present?
  end

  def stage_options
    stages.map do |stage|
      unmet = deal.unmet_stage_conditions(stage)
      StageOption.new(
        stage: stage,
        current: stage.id == deal.pipeline_stage_id,
        blocked: unmet.any?,
        blocked_title: unmet.map(&:describe_requirement).join("; ")
      )
    end
  end

  def move_url(stage)
    helpers.move_deal_path(deal, pipeline_stage_id: stage.id, source: "inline")
  end

  private

  def stages
    deal.pipeline&.pipeline_stages&.ordered.to_a
  end
end
