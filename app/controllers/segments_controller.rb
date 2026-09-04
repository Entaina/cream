class SegmentsController < ApplicationController
  include RequiresFeature
  requires_feature :marketing_segments
  before_action :set_segment, only: %i[show edit update destroy preview]

  def index
    @segments = policy_scope(current_workspace.segments).ordered
    authorize Segment
  end

  def show
    authorize @segment
    base = @segment.record_type == "Person" ? current_workspace.people : current_workspace.public_send(@segment.record_type.tableize)
    @members = @segment.resolve(base.includes(:company))
    @count = @members.count
    @pagy, @members = pagy(:offset, @members, limit: 25) if @segment.record_type == "Person"
  end

  def new
    @segment = current_workspace.segments.new(record_type: "Person", user: current_user)
    authorize @segment
  end

  def create
    @segment = current_workspace.segments.new(segment_params.merge(user: current_user))
    authorize @segment
    if @segment.save
      redirect_to @segment, notice: "Segmento creado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @segment
  end

  def update
    authorize @segment
    if @segment.update(segment_params)
      redirect_to @segment, notice: "Segmento actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @segment
    @segment.destroy
    redirect_to segments_path, notice: "Segmento eliminado.", status: :see_other
  end

  def preview
    authorize @segment, :show?
    render json: { count: @segment.resolve.count }
  end

  private

  def set_segment
    @segment = policy_scope(current_workspace.segments).find(params[:id])
  end

  def segment_params
    params.require(:segment).permit(:name, :record_type, :description, :shared, filters: {})
  end
end
