class PipelinesController < ApplicationController
  before_action :set_pipeline, only: %i[edit update destroy duplicate reorder_stages]

  def index
    @pipelines = policy_scope(current_workspace.pipelines).ordered.includes(:pipeline_stages)
  end

  def new
    @pipeline = current_workspace.pipelines.new(position: current_workspace.pipelines.count)
    3.times { |i| @pipeline.pipeline_stages.build(position: i, color: PipelineStage::COLORS[i % PipelineStage::COLORS.size]) }
    authorize @pipeline
  end

  def create
    @pipeline = current_workspace.pipelines.new(pipeline_params)
    authorize @pipeline

    if @pipeline.save
      redirect_to pipelines_path, notice: "Pipeline created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @pipeline
  end

  def update
    authorize @pipeline
    if @pipeline.update(pipeline_params)
      redirect_to pipelines_path, notice: "Pipeline updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Duplicate a pipeline's structure (stages only, no deals).
  def duplicate
    copy = @pipeline.duplicate
    authorize copy, :create?
    if copy.save
      redirect_to edit_pipeline_path(copy), notice: "Pipeline duplicated."
    else
      redirect_to pipelines_path, alert: copy.errors.full_messages.to_sentence
    end
  end

  def from_template
    unless CreamFeatures.enabled?(:pipeline_templates)
      redirect_to pipelines_path, alert: "Pipeline templates are not available yet."
      return
    end

    template_key = params[:template_key]
    pipeline = Pipeline.new(workspace: current_workspace, name: "Template")
    authorize pipeline, :create?
    pipeline = PipelineTemplate.create_pipeline!(workspace: current_workspace, template_key: template_key)
    redirect_to edit_pipeline_path(pipeline), notice: "Pipeline created from template."
  rescue KeyError
    redirect_to pipelines_path, alert: "Unknown template."
  end

  def destroy
    authorize @pipeline
    if @pipeline.destroy
      redirect_to pipelines_path, notice: "Pipeline deleted.", status: :see_other
    else
      redirect_to pipelines_path, alert: @pipeline.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def reorder_stages
    authorize @pipeline, :update?
    stage_ids = params.permit(stage_ids: [])[:stage_ids]
    if stage_ids.present? && @pipeline.reorder_stages!(stage_ids)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  private

  def set_pipeline
    @pipeline = policy_scope(current_workspace.pipelines).find(params[:id])
  end

  def pipeline_params
    params.require(:pipeline).permit(:name, :default_pipeline, card_fields: [],
      pipeline_stages_attributes: %i[id name color probability position won closed _destroy])
  end
end
