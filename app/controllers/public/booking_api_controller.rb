module Public
  class BookingApiController < ApplicationController
    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_booking_page
    before_action :silently_accept_if_abusive, only: :book
    before_action :set_calendar_client, only: :book

    rate_limit to: 60, within: 1.minute, only: %i[event_types availability],
      name: "booking_api_read",
      with: -> { render_rate_limited }
    rate_limit to: 10, within: 1.minute, only: :book,
      name: "booking_api_book",
      with: -> { render_rate_limited }

    def event_types
      locale = resolved_locale
      event_types = @booking_page.event_types.visible.ordered.map { |event_type| event_type.payload(locale:) }
      payload = {
        profile: @booking_page.profile_payload(locale:),
        event_types: event_types,
        timezone: @booking_page.timezone
      }
      expires_in 5.minutes, public: true
      render json: payload
    end

    def availability
      I18n.with_locale(resolved_locale) do
        event_type = find_event_type!
        timezone = params[:timezone].presence || @booking_page.timezone

        if params[:month].present?
          result = BookingAvailabilityService.monthly(
            booking_page: @booking_page,
            event_type:,
            month: params[:month],
            timezone:,
            client: optional_calendar_client
          )
          render json: availability_payload(result)
        elsif params[:date].present?
          result = BookingAvailabilityService.daily(
            booking_page: @booking_page,
            event_type:,
            date: params[:date],
            timezone:,
            client: optional_calendar_client
          )
          render json: availability_payload(result)
        else
          render json: {error: I18n.t("booking.errors.availability_params_required")}, status: :bad_request
        end
      end
    rescue ActiveRecord::RecordNotFound
      I18n.with_locale(resolved_locale) do
        render json: {error: I18n.t("booking.errors.event_type_not_found")}, status: :not_found
      end
    rescue ArgumentError => e
      render json: {error: e.message}, status: :bad_request
    end

    def book
      I18n.with_locale(resolved_locale) do
        event_type = find_event_type!
        result = BookingCreator.call(
          booking_page: @booking_page,
          event_type:,
          params: booking_params,
          request:,
          client: @calendar_client
        )
        render json: result.booking.confirmation_payload(locale: resolved_locale), status: :created
      rescue BookingCreator::Conflict => e
        render json: {error: e.message}, status: :conflict
      rescue BookingCreator::ValidationError => e
        render json: {error: e.message}, status: :bad_request
      rescue GoogleCalendar::Error => e
        render json: {error: e.message}, status: :service_unavailable
      rescue ActiveRecord::RecordNotFound
        render json: {error: I18n.t("booking.errors.event_type_not_found")}, status: :not_found
      end
    end

    private

    def ensure_feature_enabled
      head :not_found unless CreamFeatures.enabled?(:calendar_booking)
    end

    def set_booking_page
      @booking_page = BookingPage.active.find_by!(slug: params[:slug])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_calendar_client
      @calendar_client = optional_calendar_client
      unless @calendar_client
        connection = @booking_page.calendar_connection
        error = connection&.missing_scopes_message || I18n.t("booking.errors.calendar_not_connected")
        render json: {error: "not_connected", message: error}, status: :service_unavailable
        throw :abort
      end
    end

    def optional_calendar_client
      connection = @booking_page.calendar_connection
      return unless connection&.operational?

      GoogleCalendar::Client.new(connection)
    end

    def find_event_type!
      @booking_page.event_types.visible.find_by!(slug: params[:event_type])
    end

    def resolved_locale
      locale = params[:lang].presence || booking_params["lang"].presence ||
        request.env["HTTP_ACCEPT_LANGUAGE"].to_s[/\A[a-z]{2}/]
      locale.in?(%w[es en]) ? locale : "es"
    end

    def booking_params
      params.permit(
        :event_type, :datetime, :first_name, :last_name, :email, :phone, :message, :timezone, :lang,
        :source_page, :referrer, :utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content,
        BookingPage::HONEYPOT_FIELD, BookingPage::TIMESTAMP_FIELD,
        guests: []
      ).to_h
    end

    def silently_accept_if_abusive
      return unless bot_suspected? || throttled?

      event_type = find_event_type!
      render json: silent_booking_payload(event_type:), status: :created
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def bot_suspected?
      honeypot_triggered? || !BookingPage.submitted_after_min_time?(booking_params[BookingPage::TIMESTAMP_FIELD])
    end

    def honeypot_triggered?
      booking_params[BookingPage::HONEYPOT_FIELD].present?
    end

    def throttled?
      BookingPage.page_throttled?(@booking_page) ||
        BookingPage.email_throttled?(booking_params["email"])
    end

    def silent_booking_payload(event_type:)
      timezone = booking_params["timezone"].presence || @booking_page.timezone
      zone = ActiveSupport::TimeZone[timezone] || Time.zone
      starts_at = zone.parse(booking_params["datetime"].to_s) || Time.current
      ends_at = starts_at + event_type.duration_minutes.minutes

      payload = {
        id: 0,
        event_type: event_type.payload(locale: resolved_locale),
        starts_at: starts_at.iso8601,
        ends_at: ends_at.iso8601,
        timezone: timezone,
        display_starts_at: Booking.display_starts_at_with_zone(
          starts_at:,
          timezone:,
          locale: resolved_locale
        ),
        attendee_name: [booking_params["first_name"], booking_params["last_name"]].compact.join(" ").strip,
        attendee_email: booking_params["email"],
        guest_emails: Array(booking_params["guests"]).compact,
        location_type: event_type.location_type,
        location_address: event_type.location_address,
        meet_link: nil,
        google_event_link: nil
      }
      if event_type.reminder_will_send_at?(starts_at)
        payload[:reminder_minutes_before] = event_type.reminder_minutes_before
      end
      payload[:confirmation_email] = true if event_type.confirmation_email_enabled?
      payload
    end

    def render_rate_limited
      response.set_header("Retry-After", "60")
      I18n.with_locale(resolved_locale) do
        render json: {error: I18n.t("booking.errors.rate_limited")}, status: :too_many_requests
      end
    end

    def calendar_error_json(error)
      {
        error: error.code.to_s,
        message: error.message,
        help_url: error.help_url
      }.compact
    end

    def availability_payload(result)
      payload = {timezone: params[:timezone].presence || @booking_page.timezone}
      payload[:days] = result.days if result.days
      payload[:slots] = result.slots if result.slots
      payload[:warning] = result.warning if result.warning.present?
      payload
    end
  end
end
