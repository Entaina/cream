class ImportsController < ApplicationController
  include RequiresFeature

  requires_feature :csv_import_export
  RECORD_TYPES = %w[Person Company Deal].freeze

  skip_after_action :verify_policy_scoped

  def new
    @record_type = params[:record_type]
    raise ActionController::BadRequest unless RECORD_TYPES.include?(@record_type)

    authorize current_workspace, :import?
  end

  def create
    @record_type = params[:record_type]
    raise ActionController::BadRequest unless RECORD_TYPES.include?(@record_type)

    authorize current_workspace, :import?

    result = CsvImporter.import(@record_type, workspace: current_workspace, user: current_user, io: params[:file])

    if result.errors.empty?
      redirect_to import_redirect_path(@record_type), notice: t("flashes.imports.completed", count: result.created)
    else
      flash[:alert] = result.errors.first(5).join("; ")
      redirect_to new_import_path(record_type: @record_type)
    end
  end

  private

  def import_redirect_path(record_type)
    case record_type
    when "Person" then people_path
    when "Company" then companies_path
    when "Deal" then deals_path
    end
  end
end
