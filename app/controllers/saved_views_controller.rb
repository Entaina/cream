class SavedViewsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  before_action :set_saved_view, only: %i[update destroy]

  def create
    @saved_view = SavedView.build_from_request(
      workspace: current_workspace,
      user: current_user,
      record_type: params.require(:record_type),
      name: saved_view_params[:name],
      shared: saved_view_params[:shared],
      params: filter_params
    )
    authorize @saved_view

    if @saved_view.save
      redirect_to @saved_view.records_path(surface: saved_view_surface), notice: "View saved."
    else
      redirect_to fallback_index_path, alert: @saved_view.errors.full_messages.to_sentence
    end
  end

  def update
    @saved_view.apply_request_filters!(filter_params) if params[:update_filters].present?
    @saved_view.assign_attributes(saved_view_params) if params[:saved_view].present?

    if @saved_view.save
      redirect_to @saved_view.records_path(surface: saved_view_surface), notice: "View updated."
    else
      redirect_to @saved_view.records_path(surface: saved_view_surface), alert: @saved_view.errors.full_messages.to_sentence
    end
  end

  def destroy
    record_type = @saved_view.record_type
    @saved_view.destroy
    redirect_to fallback_index_path(record_type), notice: "View deleted.", status: :see_other
  end

  private

  def set_saved_view
    @saved_view = current_workspace.saved_views.find(params[:id])
    authorize @saved_view
  end

  def saved_view_params
    params.fetch(:saved_view, {}).permit(:name, :shared)
  end

  def filter_params
    params.permit(:q, :company_id, :owner_id, :industry, :stage, :product_id, :edition_id,
      :first_contact_from, :first_contact_to, :created_from, :created_to, :pipeline_id,
      :sort, :dir, cf: {})
  end

  def fallback_index_path(record_type = params[:record_type] || @saved_view&.record_type)
    case record_type
    when "Person" then people_path
    when "Company" then companies_path
    when "Deal" then saved_view_surface == "table" ? deals_path : board_deals_path
    else root_path
    end
  end

  def saved_view_surface
    params[:surface] == "table" ? "table" : nil
  end
end
