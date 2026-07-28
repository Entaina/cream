class SavedView < ApplicationRecord
  RECORD_TYPES = List::RECORD_TYPES

  NATIVE_FILTER_KEYS = {
    "Person" => "company_id",
    "Company" => "industry",
    "Deal" => "stage"
  }.freeze

  EXTRA_FILTER_KEYS = {
    "Person" => %w[owner_id created_from created_to],
    "Deal" => %w[product_id edition_id first_contact_from first_contact_to owner_id created_from created_to],
    "Company" => %w[owner_id created_from created_to]
  }.freeze

  belongs_to :workspace
  belongs_to :user

  validates :name, presence: true
  validates :record_type, inclusion: { in: RECORD_TYPES }
  validates :direction, inclusion: { in: %w[asc desc] }

  scope :for_type, ->(record_type) { where(record_type: record_type) }
  scope :ordered, -> { order(:position, :name) }
  scope :visible_to, ->(user) { where(user: user).or(where(shared: true)) }

  def native_filter_key = NATIVE_FILTER_KEYS.fetch(record_type)

  # Applies this view's stored filters (search, native filter, custom fields) to
  # a base scope and returns the matching relation. Mirrors the per-type index
  # filtering in PeopleController/CompaniesController/DealsController so a saved
  # view resolves to the same set of records the user sees in the list.
  def resolve(scope)
    scope = scope.search(filters["q"]) if filters["q"].present?

    native = filters[native_filter_key]
    if native.present?
      scope = apply_native_filter(scope, record_type, native)
    end

    if filters["cf"].present?
      scope = scope.merge(record_type.constantize.apply_custom_field_filters(workspace, filters["cf"]))
    end

    case record_type
    when "Person"
      scope = ListFilters.apply_owner(scope, filters["owner_id"]) if filters["owner_id"].present?
      scope = ListFilters.apply_created_at(scope, filters.symbolize_keys)
    when "Company"
      scope = ListFilters.apply_owner(scope, filters["owner_id"]) if filters["owner_id"].present?
      scope = ListFilters.apply_created_at(scope, filters.symbolize_keys)
    when "Deal"
      scope = Deal.apply_extra_filters(scope, filters.symbolize_keys)
    end

    scope
  end

  def apply_native_filter(scope, record_type, value)
    case record_type
    when "Person" then ListFilters.apply_company(scope, value)
    when "Company" then ListFilters.apply_industry(scope, value)
    when "Deal" then scope.where(pipeline_stage_id: value)
    else scope
    end
  end

  def to_filter_hash
    hash = filters.stringify_keys
    hash["sort"] = sort if sort.present?
    hash["dir"] = direction if direction.present?
    hash
  end

  def to_query_params
    { view: id }
  end

  def records_path(helpers = Rails.application.routes.url_helpers, surface: nil)
    case record_type
    when "Person" then helpers.people_path(to_query_params)
    when "Company" then helpers.companies_path(to_query_params)
    when "Deal"
      if surface == "table"
        helpers.deals_path(to_query_params)
      else
        helpers.board_deals_path(to_query_params)
      end
    end
  end

  def self.build_from_request(workspace:, user:, record_type:, name:, shared:, params:)
    native_key = NATIVE_FILTER_KEYS.fetch(record_type)
    filters = {}
    filters["q"] = params[:q] if params[:q].present?
    filters[native_key] = params[native_key] if params[native_key].present?
    if params[:cf].present?
      cf = params[:cf].respond_to?(:to_unsafe_h) ? params[:cf].to_unsafe_h : params[:cf].to_h
      filters["cf"] = cf.reject { |_, v| v.blank? }
    end
    merge_extra_filters!(filters, record_type, params)

    new(
      workspace: workspace,
      user: user,
      record_type: record_type,
      name: name,
      shared: ActiveModel::Type::Boolean.new.cast(shared) || false,
      filters: filters,
      sort: params[:sort].presence,
      direction: params[:dir].presence || "asc",
      position: next_position_for(workspace, record_type)
    )
  end

  def apply_request_filters!(params)
    native_key = native_filter_key
    filters_hash = {}
    filters_hash["q"] = params[:q] if params[:q].present?
    filters_hash[native_key] = params[native_key] if params[native_key].present?
    if params[:cf].present?
      cf = params[:cf].respond_to?(:to_unsafe_h) ? params[:cf].to_unsafe_h : params[:cf].to_h
      filters_hash["cf"] = cf.reject { |_, v| v.blank? }
    end
    self.class.merge_extra_filters!(filters_hash, record_type, params)

    self.filters = filters_hash
    self.sort = params[:sort].presence
    self.direction = params[:dir].presence || "asc"
  end

  def self.next_position_for(workspace, record_type)
    workspace.saved_views.for_type(record_type).maximum(:position).to_i + 1
  end

  def self.merge_extra_filters!(filters, record_type, params)
    (EXTRA_FILTER_KEYS[record_type] || []).each do |key|
      filters[key] = params[key] if params[key].present?
    end
  end
end
