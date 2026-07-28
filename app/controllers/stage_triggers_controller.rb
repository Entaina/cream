class StageTriggersController < ApplicationController
  include RequiresFeature
  requires_feature :stage_triggers
  before_action :set_stage, only: %i[index new create]
  before_action :set_stage_trigger, only: %i[show edit update destroy]

  def index
    @stage_triggers = policy_scope(@stage.stage_triggers).ordered
    authorize StageTrigger
  end

  def show
    authorize @stage_trigger
    @runs = @stage_trigger.runs.includes(:deal, :user).recent_first.limit(50)
  end

  def new
    @stage_trigger = @stage.stage_triggers.new(workspace: current_workspace)
    authorize @stage_trigger
  end

  def create
    @stage_trigger = @stage.stage_triggers.new(stage_trigger_params.merge(workspace: current_workspace))
    authorize @stage_trigger

    if @stage_trigger.save
      redirect_to pipeline_stage_stage_triggers_path(@stage), notice: "Disparador creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @stage_trigger
  end

  def update
    authorize @stage_trigger
    if @stage_trigger.update(stage_trigger_params)
      redirect_to pipeline_stage_stage_triggers_path(@stage_trigger.pipeline_stage), notice: "Disparador actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @stage_trigger
    stage = @stage_trigger.pipeline_stage
    @stage_trigger.destroy
    redirect_to pipeline_stage_stage_triggers_path(stage), notice: "Disparador eliminado.", status: :see_other
  end

  private

  def set_stage
    @stage = current_workspace.pipeline_stages.find(params[:pipeline_stage_id])
  end

  def set_stage_trigger
    @stage_trigger = policy_scope(current_workspace.stage_triggers).find(params[:id])
  end

  def stage_trigger_params
    params.require(:stage_trigger).permit(:name, :instructions, :execution_mode, :native_function,
      :active, :position, native_params: {})
  end
end
