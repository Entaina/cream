class EditionsController < ApplicationController
  before_action :set_product
  before_action :set_edition, only: %i[edit update destroy]

  def picker
    authorize Edition, :index?
    editions = policy_scope(@product.editions)
      .search(params[:q])
      .ordered
      .limit(10)
    render json: editions.map { |edition|
      {id: edition.id, name: edition.name, hint: edition.date_range_label}
    }
  end

  def new
    @edition = @product.editions.new
    authorize @edition
  end

  def create
    @edition = @product.editions.new(edition_params)
    authorize @edition

    if @edition.save
      respond_to do |format|
        format.html { redirect_to edit_product_path(@product), notice: t("flashes.editions.created") }
        format.json { render json: edition_json(@edition), status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: {errors: @edition.errors.full_messages}, status: :unprocessable_entity }
      end
    end
  end

  def edit
    authorize @edition
  end

  def update
    authorize @edition
    if @edition.update(edition_params)
      redirect_to edit_product_path(@product), notice: t("flashes.editions.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @edition
    if @edition.destroy
      redirect_to edit_product_path(@product), notice: t("flashes.editions.deleted"), status: :see_other
    else
      redirect_to edit_product_path(@product), alert: t("flashes.editions.in_use"), status: :see_other
    end
  end

  private

  def set_product
    @product = policy_scope(current_workspace.products).find(params[:product_id])
  end

  def set_edition
    @edition = policy_scope(current_workspace.editions).where(product_id: @product.id).find(params[:id])
  end

  def edition_params
    params.require(:edition).permit(:name, :starts_on, :ends_on)
  end

  def edition_json(edition)
    {id: edition.id, name: edition.name, hint: edition.date_range_label}
  end
end
