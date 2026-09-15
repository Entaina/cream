class StageFieldFormatsController < ApplicationController
  include RequiresFeature

  requires_feature :stage_field_formats
  before_action :set_stage, only: %i[index new create]
  before_action :set_stage_field_format, only: %i[edit update destroy]

  def index
    @stage_field_formats = policy_scope(@stage.stage_field_formats).ordered
    authorize StageFieldFormat
  end

  def new
    @stage_field_format = @stage.stage_field_formats.new(workspace: current_workspace)
    authorize @stage_field_format
  end

  def create
    @stage_field_format = @stage.stage_field_formats.new(stage_field_format_params.merge(workspace: current_workspace))
    authorize @stage_field_format

    if @stage_field_format.save
      redirect_to pipeline_stage_stage_field_formats_path(@stage), notice: "Formato creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @stage_field_format
  end

  def update
    authorize @stage_field_format
    if @stage_field_format.update(stage_field_format_params)
      redirect_to pipeline_stage_stage_field_formats_path(@stage_field_format.pipeline_stage), notice: "Formato actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @stage_field_format
    stage = @stage_field_format.pipeline_stage
    @stage_field_format.destroy
    redirect_to pipeline_stage_stage_field_formats_path(stage), notice: "Formato eliminado.", status: :see_other
  end

  private

  def set_stage
    @stage = current_workspace.pipeline_stages.find(params[:pipeline_stage_id])
  end

  def set_stage_field_format
    @stage_field_format = policy_scope(current_workspace.stage_field_formats).find(params[:id])
  end

  def stage_field_format_params
    params.require(:stage_field_format).permit(:field, :operator, :compare_value, :display_text, :active, :position)
  end
end
