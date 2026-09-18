class ProductsController < ApplicationController
  include Filterable

  remembers_list_filters only: :index
  before_action :set_product, only: %i[edit update destroy]

  SORTABLE = %w[name price segment created_at].freeze

  def index
    @products = policy_scope(current_workspace.products)
    @products = @products.search(params[:q])
    @products = @products.with_segment(params[:segment])
    @products = @products.order(sort_clause)
  end

  def new
    @product = current_workspace.products.new
    authorize @product
  end

  def create
    @product = current_workspace.products.new(product_params)
    authorize @product

    if @product.save
      redirect_to products_path, notice: t("flashes.products.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @product
    @editions = @product.editions.ordered
  end

  def update
    authorize @product
    if @product.update(product_params)
      redirect_to products_path, notice: t("flashes.products.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product
    if @product.destroy
      redirect_to products_path, notice: t("flashes.products.deleted"), status: :see_other
    else
      redirect_to products_path, alert: t("flashes.products.in_use"), status: :see_other
    end
  end

  private

  def set_product
    @product = policy_scope(current_workspace.products).find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :segment)
  end

  def sort_clause
    column = SORTABLE.include?(params[:sort]) ? params[:sort] : "name"
    direction = (params[:dir] == "desc") ? :desc : :asc
    {column => direction}
  end
end
