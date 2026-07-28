module ViewScoped
  extend ActiveSupport::Concern

  included do
    helper_method :index_query_params, :view_filters_changed?, :filter_form_params, :filters_active?, :filter_value
  end

  private

  def load_saved_views(record_type)
    @record_type = record_type
    @native_filter_key = SavedView::NATIVE_FILTER_KEYS.fetch(record_type)
    @extra_filter_keys = SavedView::EXTRA_FILTER_KEYS[record_type] || []
    @saved_views = policy_scope(current_workspace.saved_views).for_type(record_type).ordered
    @active_view = @saved_views.find_by(id: params[:view]) if params[:view].present?
    @effective_filters = build_effective_filters
  end

  def build_effective_filters
    base = if @active_view
      @active_view.to_filter_hash.symbolize_keys
    else
      {}
    end

    overrides = {}
    overrides[:q] = params[:q] if params.key?(:q)
    overrides[@native_filter_key.to_sym] = params[@native_filter_key] if params.key?(@native_filter_key)
    overrides[:cf] = params[:cf] if params.key?(:cf)
    overrides[:sort] = params[:sort] if params.key?(:sort)
    overrides[:dir] = params[:dir] if params.key?(:dir)
    overrides[:closed] = params[:closed] if params.key?(:closed)
    @extra_filter_keys.each do |key|
      overrides[key.to_sym] = params[key] if params.key?(key)
    end

    base.merge(overrides) { |_key, _old, new| new }
  end

  def filter_value(key)
    @effective_filters[key.to_sym]
  end

  def apply_sorting(scope, sortable:, default_column:)
    direction = (filter_value(:dir) == "desc") ? :desc : :asc
    sort_param = filter_value(:sort).to_s

    if sort_param.start_with?("cf:")
      scope.sorted_by_custom_field(current_workspace, sort_param.delete_prefix("cf:"), direction)
    else
      column = sortable.include?(sort_param) ? sort_param : default_column
      scope.order(column => direction)
    end
  end

  def index_query_params(overrides = {})
    query = {}
    query[:view] = @active_view.id if @active_view
    @effective_filters.each do |key, value|
      next if value.blank?

      query[key] = if key == :cf && value.respond_to?(:to_unsafe_h)
        value.to_unsafe_h
      else
        value
      end
    end
    query.merge!(overrides).compact
  end

  def view_filters_changed?
    return false unless @active_view

    stored = @active_view.to_filter_hash
    effective = stringify_effective_filters
    if action_name == "board"
      stored = stored.except("stage")
      effective = effective.except("stage")
    end

    stored != effective
  end

  def stringify_effective_filters
    hash = {}
    hash["q"] = filter_value(:q) if filter_value(:q).present?
    native = filter_value(@native_filter_key)
    hash[@native_filter_key] = native if native.present?
    cf = filter_value(:cf)
    hash["cf"] = cf.respond_to?(:to_unsafe_h) ? cf.to_unsafe_h : cf if cf.present?
    hash["sort"] = filter_value(:sort) if filter_value(:sort).present?
    hash["dir"] = filter_value(:dir) if filter_value(:dir).present?
    @extra_filter_keys.each do |key|
      value = filter_value(key.to_sym)
      hash[key] = value if value.present?
    end
    hash
  end

  def filters_active?
    filter_value(:q).present? ||
      filter_value(@native_filter_key).present? ||
      filter_value(:cf).present? ||
      @extra_filter_keys.any? { |key| filter_value(key.to_sym).present? } ||
      @active_view.present?
  end

  def filter_form_params
    query = {}
    query[:q] = filter_value(:q) if filter_value(:q).present?
    native = filter_value(@native_filter_key)
    query[@native_filter_key.to_sym] = native if native.present?
    cf = filter_value(:cf)
    if cf.present?
      cf_hash = cf.respond_to?(:to_unsafe_h) ? cf.to_unsafe_h : cf.to_h
      query[:cf] = cf_hash
    end
    query[:sort] = filter_value(:sort) if filter_value(:sort).present?
    query[:dir] = filter_value(:dir) if filter_value(:dir).present?
    query[:closed] = filter_value(:closed) if filter_value(:closed).present?
    @extra_filter_keys.each do |key|
      value = filter_value(key.to_sym)
      query[key.to_sym] = value if value.present?
    end
    query[:view] = @active_view.id if @active_view
    query
  end
end
