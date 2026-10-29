class BookingPagesController < ApplicationController
  include RequiresFeature

  requires_feature :calendar_booking

  before_action :set_booking_page, only: %i[edit update destroy]

  def index
    @booking_pages = policy_scope(current_workspace.booking_pages).ordered.includes(:host, :co_hosts, :pipeline, :event_types)
    @calendar_connection = current_workspace.calendar_connections.find_by(user: current_user)
    authorize BookingPage
  end

  def new
    @booking_page = current_workspace.booking_pages.new(
      active: true,
      host: current_user,
      timezone: "Europe/Madrid",
      booking_window_days: 60
    )
    @booking_page.event_types.build(BookingEventType.blank_attributes)
    authorize @booking_page
    load_form_options
  end

  def create
    @booking_page = current_workspace.booking_pages.new(booking_page_params)
    @booking_page.host = current_user
    authorize @booking_page

    if @booking_page.save
      notify_new_co_hosts(@booking_page.co_host_ids)
      redirect_to booking_pages_path, notice: t("flashes.booking_pages.created")
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @booking_page
    load_form_options
  end

  def update
    authorize @booking_page
    previous_co_host_ids = @booking_page.co_host_ids
    attributes = booking_page_params
    calendar_ids = attributes.delete(:calendar_ids)

    if @booking_page.update_as(current_user, attributes, calendar_ids:)
      notify_new_co_hosts(@booking_page.co_host_ids - previous_co_host_ids)
      redirect_to booking_pages_path, notice: t("flashes.booking_pages.updated")
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @booking_page
    @booking_page.destroy
    redirect_to booking_pages_path, notice: t("flashes.booking_pages.deleted"), status: :see_other
  end

  def calendars
    authorize BookingPage
    connection = current_workspace.calendar_connections.find_by(user: current_user)
    unless connection&.connected?
      render json: {error: "not_connected"}, status: :unprocessable_entity
      return
    end
    if (message = connection.missing_scopes_message)
      render json: {error: "insufficient_scopes", message: message}, status: :unprocessable_entity
      return
    end

    items = GoogleCalendar::Client.new(connection).list_calendars
    render json: {calendars: items}
  rescue GoogleCalendar::Error => e
    render json: calendar_error_json(e), status: :service_unavailable
  end

  private

  def set_booking_page
    @booking_page = policy_scope(current_workspace.booking_pages).find(params[:id])
  end

  def load_form_options
    host = @booking_page.host || current_user
    @co_host_candidates = current_workspace.users.where.not(id: host.id).order(:name)
    @pipelines = current_workspace.pipelines.ordered
    @email_templates = current_workspace.email_templates.visible_to(current_user).ordered
    @booking_success_templates = current_workspace.lead_form_templates.booking_pages.ordered
    @user_calendar_connection = current_workspace.calendar_connections.find_by(user: current_user)
    calendar_result = load_user_calendars(@user_calendar_connection)
    @available_calendars = calendar_result[:calendars]
    @calendars_load_error = calendar_result.dig(:error, :message)
    @calendars_load_error_code = calendar_result.dig(:error, :code)
    @calendars_load_help_url = calendar_result.dig(:error, :help_url)
    @pending_calendar_participants = @booking_page.participants.select { |participant| participant.calendar_ids.blank? }.map { |participant| participant.user.name }
    sync_selected_calendar_ids!
  end

  def load_user_calendars(connection)
    return {calendars: [], error: nil} unless connection&.connected?
    if (message = connection.missing_scopes_message)
      return {calendars: [], error: {code: :insufficient_scopes, message: message}}
    end

    {calendars: GoogleCalendar::Client.new(connection).list_calendars, error: nil}
  rescue GoogleCalendar::Error => e
    {calendars: [], error: {code: e.code, message: e.message, help_url: e.help_url}}
  end

  # Only the current user's own calendars are ever listed or selected. The host
  # defaults to their primary calendar; a co-host with no selection has no slots.
  def sync_selected_calendar_ids!
    ids = @booking_page.calendar_ids_for(current_user).map(&:to_s).reject(&:blank?)
    @selected_calendar_ids = ids
    return if @available_calendars.blank?

    available_ids = @available_calendars.map { |calendar| calendar[:id] }
    primary = @available_calendars.find { |calendar| calendar[:primary] }

    if ids.include?("primary")
      ids = ids.reject { |id| id == "primary" }
      ids.unshift(primary[:id]) if primary
    end

    default = (@booking_page.host_id == current_user.id) ? [primary&.dig(:id) || available_ids.first] : []
    @selected_calendar_ids = ids.select { |id| available_ids.include?(id) }.presence || default
  end

  def notify_new_co_hosts(user_ids)
    BookingPageCoHostNotifier.call(booking_page: @booking_page, user_ids:, actor: current_user)
  end

  def booking_page_params
    params.require(:booking_page).permit(
      :name, :slug, :crm_association, :pipeline_id, :reuse_existing_deal, :welcome_message, :avatar_url, :logo_url,
      :timezone, :booking_window_days, :active, :success_template_id,
      calendar_ids: [], co_host_ids: [],
      event_types_attributes: [
        :id, :slug, :color, :duration_minutes, :location_type, :location_address,
        :buffer_before_minutes, :buffer_after_minutes, :slot_increment_minutes,
        :min_notice_hours, :reminder_minutes_before, :email_template_id, :success_template_id, :visible, :position, :weekly_hours, :_destroy,
        {name_i18n: {}, description_i18n: {}, confirmation_message_i18n: {}}
      ]
    ).tap do |permitted|
      permitted[:calendar_ids] = Array(permitted[:calendar_ids]).map(&:to_s).reject(&:blank?)
      permitted[:co_host_ids] = permitted_co_host_ids(permitted[:co_host_ids]) if permitted.key?(:co_host_ids)
      if permitted[:pipeline_id].present?
        permitted[:pipeline_id] = current_workspace.pipelines.find(permitted[:pipeline_id]).id
      end
      event_types = permitted[:event_types_attributes]
      event_types = event_types.values if event_types.respond_to?(:values)
      Array(event_types).each do |attrs|
        next unless attrs.is_a?(ActionController::Parameters) || attrs.is_a?(Hash)

        if attrs[:email_template_id].present?
          event_type_id = attrs[:id].presence || attrs["id"].presence
          existing = @booking_page&.event_types&.find_by(id: event_type_id)
          attrs[:email_template_id] = resolve_email_template_id(
            attrs[:email_template_id],
            current_id: existing&.email_template_id
          )
        end
      end
    end
  end

  # Only other workspace members can be added; the host can never be a co-host.
  def permitted_co_host_ids(ids)
    host_id = @booking_page&.host_id || current_user.id
    requested = Array(ids).reject(&:blank?).map(&:to_i)
    current_workspace.users.where(id: requested).where.not(id: host_id).pluck(:id)
  end

  def calendar_error_json(error)
    {
      error: error.code.to_s,
      message: error.message,
      help_url: error.help_url
    }.compact
  end
end
