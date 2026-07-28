# Persistencia de filtros de listado durante la sesión del usuario.
# El payload se guarda en BD (ListFilterState), no en la cookie de sesión.
# - Sin query string: restaura filtros y página guardados si existen (redirect 303 con params).
# - Con filtros en la URL: guarda (incluye page cuando viene; al cambiar filtros sin page se resetea).
# - Solo ?page=N: fusiona la página con el estado guardado y redirige si hay filtros activos.
# - clear_filters=1: borra almacén y redirige al listado limpio.
module Filterable
  extend ActiveSupport::Concern

  EXCLUDED_KEYS = %w[controller action format clear_filters utf8 commit].freeze
  # View toggles, not list filters — must not be restored from stored state.
  NON_PERSISTED_FILTER_KEYS = %w[closed].freeze

  class_methods do
    def remembers_list_filters(only:)
      before_action :restore_or_persist_list_filters, only: only
    end
  end

  private

  def restore_or_persist_list_filters
    return unless list_filters_restorable?

    if params[:clear_filters].present?
      ListFilterState.delete(
        session: Current.session,
        workspace: current_workspace,
        key: list_filter_state_key
      )
      redirect_to list_filters_redirect_url, status: :see_other
      return
    end

    filtered = raw_list_filter_params
    if filtered.present?
      if page_only_params?(filtered)
        handle_page_only_request(filtered)
      else
        persist_list_filter_params(filtered)
      end
      return
    end

    stored = load_stored_list_filters
    return if stored.blank? || request.query_string.present?

    redirect_to list_filters_redirect_url(**stored.symbolize_keys), status: :see_other
  end

  def list_filters_restorable?
    return false unless request.get? || request.head?
    return false unless request.format.html?
    return false if Current.session.blank?
    return false if current_workspace.blank?

    true
  end

  def list_filter_state_key
    "#{controller_path}##{action_name}"
  end

  def load_stored_list_filters
    stored = ListFilterState.read(
      session: Current.session,
      workspace: current_workspace,
      key: list_filter_state_key
    )
    stored&.except(*NON_PERSISTED_FILTER_KEYS)
  end

  def raw_list_filter_params
    raw = request.query_parameters.except(*EXCLUDED_KEYS)
    raw = raw.to_unsafe_h if raw.is_a?(ActionController::Parameters)
    raw.to_h.stringify_keys
  end

  def page_only_params?(filtered)
    filtered.keys == ["page"]
  end

  def handle_page_only_request(filtered)
    stored = load_stored_list_filters || {}
    merged = stored.merge(filtered)

    persist_list_filter_params(merged)

    return unless stored.except("page").present?

    redirect_to list_filters_redirect_url(**merged.symbolize_keys), status: :see_other
  end

  def persist_list_filter_params(filtered)
    ListFilterState.write(
      session: Current.session,
      workspace: current_workspace,
      key: list_filter_state_key,
      params: filtered.except(*NON_PERSISTED_FILTER_KEYS)
    )
  end

  def list_filters_redirect_url(**opts)
    if controller_path == "deals" && action_name == "board"
      board_deals_path(**opts)
    else
      route_suffix = controller_path.tr("/", "_")
      send(:"#{route_suffix}_path", **opts)
    end
  end
end
