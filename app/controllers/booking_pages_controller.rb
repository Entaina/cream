class BookingPagesController < ApplicationController
  include RequiresFeature

  requires_feature :calendar_booking

  before_action :set_booking_page, only: %i[edit update destroy]

  def index
    @booking_pages = policy_scope(current_workspace.booking_pages).ordered.includes(:host, :pipeline, :event_types)
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
    apply_default_calendar_ids!
  end

  def create
    @booking_page = current_workspace.booking_pages.new(booking_page_params)
    authorize @booking_page

    if @booking_page.save
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
    if @booking_page.update(booking_page_params)
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
    host = current_workspace.users.find(params[:host_id])
    connection = current_workspace.calendar_connections.find_by(user: host)
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
    @hosts = current_workspace.users.order(:name)
    @pipelines = current_workspace.pipelines.ordered
    @email_templates = current_workspace.email_templates.visible_to(current_user).ordered
    @booking_success_templates = current_workspace.lead_form_templates.booking_pages.ordered
    host = @booking_page.host || current_user
    @host_calendar_connection = current_workspace.calendar_connections.find_by(user: host)
    calendar_result = load_host_calendars(@host_calendar_connection)
    @available_calendars = calendar_result[:calendars]
    @calendars_load_error = calendar_result.dig(:error, :message)
    @calendars_load_error_code = calendar_result.dig(:error, :code)
    @calendars_load_help_url = calendar_result.dig(:error, :help_url)
    sync_calendar_ids_with_available!
  end

  def load_host_calendars(connection)
    return {calendars: [], error: nil} unless connection&.connected?
    if (message = connection.missing_scopes_message)
      return {calendars: [], error: {code: :insufficient_scopes, message: message}}
    end

    {calendars: GoogleCalendar::Client.new(connection).list_calendars, error: nil}
  rescue GoogleCalendar::Error => e
    {calendars: [], error: {code: e.code, message: e.message, help_url: e.help_url}}
  end

  def apply_default_calendar_ids!
    return if Array(@booking_page.calendar_ids).reject(&:blank?).any?
    return if @available_calendars.blank?

    primary = @available_calendars.find { |calendar| calendar[:primary] }
    @booking_page.calendar_ids = [primary&.dig(:id) || @available_calendars.first[:id]]
  end

  def sync_calendar_ids_with_available!
    return if @available_calendars.blank?

    available_ids = @available_calendars.map { |calendar| calendar[:id] }
    ids = Array(@booking_page.calendar_ids).map(&:to_s).reject(&:blank?)

    if ids.include?("primary")
      primary = @available_calendars.find { |calendar| calendar[:primary] }
      ids = ids.reject { |id| id == "primary" }
      ids.unshift(primary[:id]) if primary
    end

    synced = ids.select { |id| available_ids.include?(id) }
    @booking_page.calendar_ids = synced.presence || [@available_calendars.find { |c| c[:primary] }&.dig(:id) || available_ids.first]
  end

  def booking_page_params
    params.require(:booking_page).permit(
      :name, :slug, :host_id, :pipeline_id, :reuse_existing_deal, :welcome_message, :avatar_url, :logo_url,
      :timezone, :booking_window_days, :active, :success_template_id,
      calendar_ids: [],
      event_types_attributes: [
        :id, :slug, :color, :duration_minutes, :location_type, :location_address,
        :buffer_before_minutes, :buffer_after_minutes, :slot_increment_minutes,
        :min_notice_hours, :reminder_minutes_before, :email_template_id, :success_template_id, :visible, :position, :weekly_hours, :_destroy,
        {name_i18n: {}, description_i18n: {}}
      ]
    ).tap do |permitted|
      permitted[:calendar_ids] = Array(permitted[:calendar_ids]).map(&:to_s).reject(&:blank?)
    end
  end

  def calendar_error_json(error)
    {
      error: error.code.to_s,
      message: error.message,
      help_url: error.help_url
    }.compact
  end
end
