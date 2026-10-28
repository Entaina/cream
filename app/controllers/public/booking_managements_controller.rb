module Public
  class BookingManagementsController < ApplicationController
    include WorkspaceTemplateCsp

    layout "public_booking"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_booking_page
    before_action :set_booking_from_token
    before_action :set_public_locale

    rate_limit to: 30, within: 1.minute, only: %i[cancel destroy reschedule], name: "booking_manage"

    def cancel
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      render_cancel_state
    end

    def destroy
      unless @booking.cancellable?
        render_cancel_state
        return
      end

      connection = @booking_page.calendar_connection
      client = connection&.connected? ? GoogleCalendar::Client.new(connection) : nil
      BookingCanceller.call(booking: @booking, client:)
      @booking.reload
      @cancelled = true
      render :cancelled
    rescue GoogleCalendar::Error => e
      @cancel_error = e.message
      render :cancel, status: :unprocessable_entity
    end

    def reschedule
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      unless @booking.reschedulable?
        render :not_modifiable
        return
      end

      @event_type = @booking.booking_event_type
      @reschedule_mode = true
      render "public/bookings/show"
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

    def set_booking_from_token
      @booking = Booking.includes(:booking_event_type, :booking_page).find_by_manage_token(params[:token])
      head :not_found if @booking.blank? || @booking.booking_page_id != @booking_page.id
    end

    def set_public_locale
      @locale = resolved_locale
      I18n.locale = @locale.to_sym
    end

    def resolved_locale
      locale = params[:lang].presence || @booking&.guest_locale ||
        request.env["HTTP_ACCEPT_LANGUAGE"].to_s[/\A[a-z]{2}/]
      locale.in?(%w[es en]) ? locale : "es"
    end

    def render_cancel_state
      if @booking.status == "cancelled" || @cancelled
        render :cancelled
      elsif !@booking.cancellable?
        render :not_modifiable
      else
        render :cancel
      end
    end
  end
end
