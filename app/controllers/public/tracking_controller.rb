module Public
  class TrackingController < ApplicationController
    allow_unauthenticated_access only: %i[create script]
    skip_before_action :set_current_workspace, :ensure_workspace_membership
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped
    skip_forgery_protection only: %i[create script]

    rate_limit to: 120, within: 1.minute, only: :create, name: "page_view_create"

    def create
      return head :not_found unless CreamFeatures.enabled?(:web_tracking)

      workspace = Workspace.find_by(slug: params[:workspace])
      return head :not_found unless workspace

      anonymous_id = params[:anonymous_id].presence || cookies[:cream_aid].presence || SecureRandom.uuid
      cookies[:cream_aid] = {value: anonymous_id, expires: 1.year.from_now, httponly: true, same_site: :lax}

      person = identify_person(workspace, anonymous_id)
      PageView.record!(
        workspace: workspace,
        anonymous_id: anonymous_id,
        url: params[:url].to_s.truncate(2048),
        referrer: params[:referrer]&.to_s&.truncate(2048),
        utm: params.permit(:utm_source, :utm_medium, :utm_campaign, :utm_term, :utm_content).to_h,
        session_id: params[:session_id],
        person: person,
        metadata: {"user_agent" => request.user_agent, "ip" => request.remote_ip}
      )
      Marketing::ScoringEngine.apply_event!(person: person, event: "page_view", metadata: {"url" => params[:url]}) if person
      head :ok
    end

    def script
      return head :not_found unless CreamFeatures.enabled?(:web_tracking)

      render js: render_to_string(partial: "public/tracking/cream", formats: [:js]), content_type: "application/javascript"
    end

    private

    def identify_person(workspace, anonymous_id)
      workspace.page_views.where(anonymous_id: anonymous_id).where.not(person_id: nil).order(occurred_at: :desc).first&.person
    end
  end
end
