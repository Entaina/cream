class EditionsController < ApplicationController
  before_action :set_edition, only: %i[edit update destroy]

  def index
    @editions = policy_scope(current_workspace.editions).ordered
  end

  def picker
    authorize Edition, :index?
    editions = policy_scope(current_workspace.editions)
      .search(params[:q])
      .ordered
      .limit(10)
    render json: editions.map { |edition|
      { id: edition.id, name: edition.name, hint: edition.date_range_label }
    }
  end

  def new
    @edition = current_workspace.editions.new
    authorize @edition
  end

  def create
    @edition = current_workspace.editions.new(edition_params)
    authorize @edition

    if @edition.save
      respond_to do |format|
        format.html { redirect_to editions_path, notice: "Edition created." }
        format.json { render json: edition_json(@edition), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @edition.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @edition
  end

  def update
    authorize @edition
    if @edition.update(edition_params)
      redirect_to editions_path, notice: "Edition updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @edition
    if @edition.destroy
      redirect_to editions_path, notice: "Edition deleted.", status: :see_other
    else
      redirect_to editions_path, alert: "Can't delete an edition in use by a deal.", status: :see_other
    end
  end

  private

  def set_edition
    @edition = policy_scope(current_workspace.editions).find(params[:id])
  end

  def edition_params
    params.require(:edition).permit(:name, :starts_on, :ends_on)
  end

  def edition_json(edition)
    { id: edition.id, name: edition.name, hint: edition.date_range_label }
  end
end
