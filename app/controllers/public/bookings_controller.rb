module Public
  class BookingsController < ApplicationController
    include WorkspaceTemplateCsp

    layout "public_booking"

    allow_unauthenticated_access
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    before_action :ensure_feature_enabled
    before_action :set_booking_page
    before_action :set_event_type, if: -> { params[:event_type].present? }
    before_action :set_public_booking_locale, only: :show

    rate_limit to: 60, within: 1.minute, only: %i[show received], name: "booking_page_show"

    def show
      @reschedule_mode = false
      response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
    end

    def received
      event_type = @booking_page.event_types.visible.find_by!(slug: params[:evento])
      template = event_type.resolved_success_template
      return head :not_found if template.blank?

      @locale = resolved_locale
      I18n.locale = @locale.to_sym
      @received_page_html = BookingTemplates::ReceivedRenderer.render(
        workspace: @booking_page.workspace,
        template: template,
        view_context: view_context,
        event_slug: event_type.slug,
        booking_page: @booking_page
      )
      render :received, layout: "public_lead_form"
    rescue ActiveRecord::RecordNotFound, Liquid::Error
      head :not_found
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

    def set_event_type
      @event_type = @booking_page.event_types.visible.find_by!(slug: params[:event_type])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def set_public_booking_locale
      @locale = resolved_locale
      I18n.locale = @locale.to_sym
    end

    def resolved_locale
      locale = params[:lang].presence || request.env["HTTP_ACCEPT_LANGUAGE"].to_s[/\A[a-z]{2}/]
      locale.in?(%w[es en]) ? locale : "es"
    end
  end
end
