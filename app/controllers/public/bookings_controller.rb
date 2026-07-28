module Public
  class BookingsController < ApplicationController
    layout "public_booking"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_booking_page

    rate_limit to: 60, within: 1.minute, only: :show, name: "booking_page_show"

    def show
      @locale = resolved_locale
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
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

    def resolved_locale
      locale = params[:lang].presence || request.env["HTTP_ACCEPT_LANGUAGE"].to_s[/\A[a-z]{2}/]
      locale.in?(%w[es en]) ? locale : "es"
    end
  end
end
