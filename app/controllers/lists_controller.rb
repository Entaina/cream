class ListsController < ApplicationController
  before_action :set_list, only: %i[show edit update destroy]

  def index
    @lists = policy_scope(current_workspace.lists).order(:name).includes(:list_entries)
  end

  def show
    authorize @list
    @entries = visible_list_entries
    @candidates = candidate_records
  end

  def new
    @list = current_workspace.lists.new
    authorize @list
  end

  def create
    @list = current_workspace.lists.new(list_params)
    authorize @list

    if @list.save
      redirect_to @list, notice: "List created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @list
  end

  def update
    authorize @list
    if @list.update(list_params)
      redirect_to @list, notice: "List updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @list
    @list.destroy
    redirect_to lists_path, notice: "List deleted.", status: :see_other
  end

  private

  def set_list
    @list = policy_scope(current_workspace.lists).find(params[:id])
  end

  def list_params
    params.require(:list).permit(:name, :record_type, :color)
  end

  def visible_list_entries
    entries = @list.list_entries.includes(:record)
    return entries unless @list.record_type == "Deal"

    entries.where(record_type: "Deal", record_id: policy_scope(current_workspace.deals).select(:id))
  end

  def candidate_records
    scope = case @list.record_type
    when "Person" then current_workspace.people.order(:first_name, :last_name)
    when "Company" then current_workspace.companies.order(:name)
    when "Deal" then policy_scope(current_workspace.deals).order(:name)
    end
    existing_ids = @list.list_entries.where(record_type: @list.record_type).pluck(:record_id)
    scope.where.not(id: existing_ids)
  end
end
