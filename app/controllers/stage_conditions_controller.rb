class StageConditionsController < ApplicationController
  include RequiresFeature

  requires_feature :stage_conditions
  before_action :set_stage, only: %i[index new create]
  before_action :set_stage_condition, only: %i[edit update destroy]

  def index
    @stage_conditions = policy_scope(@stage.stage_conditions).ordered
    authorize StageCondition
  end

  def new
    @stage_condition = @stage.stage_conditions.new(workspace: current_workspace)
    authorize @stage_condition
  end

  def create
    @stage_condition = @stage.stage_conditions.new(stage_condition_params.merge(workspace: current_workspace))
    authorize @stage_condition

    if @stage_condition.save
      redirect_to pipeline_stage_stage_conditions_path(@stage), notice: t("stage_conditions.flash.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @stage_condition
  end

  def update
    authorize @stage_condition
    if @stage_condition.update(stage_condition_params)
      redirect_to pipeline_stage_stage_conditions_path(@stage_condition.pipeline_stage),
        notice: t("stage_conditions.flash.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @stage_condition
    stage = @stage_condition.pipeline_stage
    @stage_condition.destroy
    redirect_to pipeline_stage_stage_conditions_path(stage), notice: t("stage_conditions.flash.destroyed"),
      status: :see_other
  end

  private

  def set_stage
    @stage = current_workspace.pipeline_stages.find(params[:pipeline_stage_id])
  end

  def set_stage_condition
    @stage_condition = policy_scope(current_workspace.stage_conditions).find(params[:id])
  end

  def stage_condition_params
    params.require(:stage_condition).permit(:field, :operator, :compare_value, :active, :position)
  end
end
