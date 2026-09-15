class ExportsController < ApplicationController
  include RequiresFeature

  requires_feature :csv_import_export
  include ViewScoped

  skip_after_action :verify_policy_scoped

  RECORD_TYPES = %w[Person Company Deal].freeze

  def show
    @record_type = params[:record_type]
    raise ActionController::BadRequest unless RECORD_TYPES.include?(@record_type)

    authorize current_workspace, :export?
    load_saved_views(@record_type)
    scope = filtered_scope(@record_type)
    custom_fields = current_workspace.custom_fields.where(record_type: @record_type).ordered
    csv = CsvExporter.export(@record_type, scope: scope, custom_fields: custom_fields)

    send_data csv, filename: "#{@record_type.downcase.pluralize}-#{Date.current}.csv", type: "text/csv"
  end

  private

  def filtered_scope(record_type)
    case record_type
    when "Person"
      scope = policy_scope(current_workspace.people).includes(:company, :owner)
      scope = scope.search(filter_value(:q))
      scope = scope.where(company_id: filter_value(:company_id)) if filter_value(:company_id).present?
      scope = scope.where(owner_id: filter_value(:owner_id)) if filter_value(:owner_id).present?
      scope.merge(Person.apply_custom_field_filters(current_workspace, filter_value(:cf)))
    when "Company"
      scope = policy_scope(current_workspace.companies)
      scope = scope.search(filter_value(:q))
      scope = scope.where(industry: filter_value(:industry)) if filter_value(:industry).present?
      scope.merge(Company.apply_custom_field_filters(current_workspace, filter_value(:cf)))
    when "Deal"
      scope = policy_scope(current_workspace.deals).includes(:company, :pipeline_stage)
      scope = Deal.filter_by(scope, @effective_filters)
      scope.merge(Deal.apply_custom_field_filters(current_workspace, filter_value(:cf)))
    end
  end
end
